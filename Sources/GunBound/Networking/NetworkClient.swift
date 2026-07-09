import Foundation
import GunBoundProtocol

/// A client-side connection to a GunBound world server: opens a TCP socket,
/// performs the nonce + login handshake, and then runs a background **read
/// loop** — the client-side counterpart of the decompiled
/// `ProcessIncomingPackets` pump. Every inbound packet is reassembled from
/// the byte stream (packets can arrive split or coalesced) and routed:
/// replies wake the `request()` call awaiting that opcode, notifications are
/// delivered on the `pushes` stream, and anything else parks in a mailbox
/// until a matching `request()` arrives (so replies that beat their waiter
/// are never lost).
///
/// Generic over the socket type (mirroring `Connection<Socket>`'s existing
/// pattern) purely so tests can substitute a mock `GunBoundSocketTCP`
/// feeding it canned bytes captured from a real server, instead of opening
/// an actual connection — production code always uses
/// `NetworkClient<GunBoundSocketIPv4TCP>`.
public actor NetworkClient<Socket: GunBoundSocketTCP & Sendable> {

    public enum Error: Swift.Error, Equatable {
        case invalidAddress(String)
        case notAuthenticated
        /// The connection ended (EOF or a socket error) while a request was
        /// waiting for its reply.
        case disconnected
    }

    private let socket: Socket

    private let encoder = GunBoundEncoder()

    private let decoder = GunBoundDecoder()

    /// Set once `authenticate(username:password:)` succeeds — every
    /// opcode marked `isEncrypted` after login needs this to
    /// encrypt/decrypt its packet body, mirroring `Connection.key`.
    public private(set) var sessionKey: Key?

    /// Unsolicited server notifications (room updates, channel users, …),
    /// in arrival order. Single-consumer: one screen/view-model task should
    /// iterate this at a time. Finishes when the connection ends.
    public let pushes: AsyncStream<ServerPush>
    private let pushContinuation: AsyncStream<ServerPush>.Continuation

    /// One waiter per expected reply opcode, FIFO within an opcode.
    private var pending: [Opcode: [CheckedContinuation<Packet, Swift.Error>]] = [:]

    /// Replies that arrived before their `request()` registered a waiter —
    /// also how the strictly-sequential mock tests keep working: their canned
    /// responses are all read (and parked here) the moment the loop starts.
    private var mailbox: [Packet] = []

    /// Unparsed bytes between reads (TCP can split/coalesce packets).
    private var reassembly: [UInt8] = []

    private var readTask: Task<Void, Never>?
    private var isFinished = false

    private init(socket: Socket) {
        self.socket = socket
        (self.pushes, self.pushContinuation) = AsyncStream.makeStream(of: ServerPush.self)
    }

    /// Opens a TCP connection to `config.serverAddress`:`config.serverPort`
    /// and starts the read loop.
    public static func connect(_ config: NetworkConfig) async throws -> NetworkClient<Socket> {
        guard let destination = GunBoundAddress(address: config.serverAddress, port: config.serverPort) else {
            throw Error.invalidAddress(config.serverAddress)
        }
        guard let local = GunBoundAddress(address: "0.0.0.0", port: 0) else {
            throw Error.invalidAddress("0.0.0.0")
        }
        let socket = try await Socket.client(address: local, destination: destination)
        let client = NetworkClient(socket: socket)
        await client.startReading()
        return client
    }

    public func close() async {
        readTask?.cancel()
        finish()
        await socket.close()
    }

    // MARK: - Read loop

    private func startReading() {
        guard readTask == nil else { return }
        readTask = Task { await self.readLoop() }
    }

    private func readLoop() async {
        while !Task.isCancelled {
            let data: Data
            do {
                data = try await socket.recieve(Packet.maxSize)
            } catch {
                break  // socket closed or failed
            }
            guard !data.isEmpty else { break }  // EOF
            reassembly.append(contentsOf: data)
            drainReassembly()
        }
        finish()
    }

    /// Extracts every complete packet from the reassembly buffer (the wire
    /// header's first two bytes are the packet's total length, little-endian)
    /// and routes each one. Unknown opcodes are skipped; a nonsensical length
    /// means the stream is corrupt, so the connection is torn down.
    private func drainReassembly() {
        while reassembly.count >= Packet.minSize {
            let length = Int(reassembly[0]) | (Int(reassembly[1]) << 8)
            guard length >= Packet.minSize, length <= Packet.maxSize else {
                readTask?.cancel()
                finish()
                return
            }
            guard reassembly.count >= length else { return }  // partial packet
            let bytes = Array(reassembly[0..<length])
            reassembly.removeFirst(length)
            guard let packet = Packet(data: bytes) else {
                // Unknown opcode or malformed header — skip this packet.
                continue
            }
            route(packet)
        }
    }

    /// Routes one inbound packet: a registered waiter for its opcode wins,
    /// else notifications go to `pushes`, else it parks in the mailbox for a
    /// later `request()`. Encrypted opcodes (e.g. the chat broadcast
    /// `0x201F`) are decrypted first, mirroring the server `Connection`'s
    /// read path — an undecryptable body still routes, undecoded.
    private func route(_ rawPacket: Packet) {
        var packet = rawPacket
        if packet.opcode.isEncrypted, let key = sessionKey,
           let decrypted = try? packet.decrypt(key: key) {
            packet = decrypted
        }
        if var waiters = pending[packet.opcode], !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            pending[packet.opcode] = waiters
            continuation.resume(returning: packet)
        } else if packet.opcode.type == .notification {
            pushContinuation.yield(ServerPush(packet, decoder: decoder))
        } else {
            mailbox.append(packet)
        }
    }

    /// Ends the connection's inbound side: fails every waiting request and
    /// finishes the push stream. Idempotent.
    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        pushContinuation.finish()
        let waiters = pending.values.flatMap { $0 }
        pending.removeAll()
        for continuation in waiters {
            continuation.resume(throwing: Error.disconnected)
        }
    }

    /// Opens a short-lived connection to a broker/directory server (default
    /// port `8372`, distinct from a world server's port) and fetches the
    /// list of available world servers — the real login flow's first step,
    /// which a single hardcoded `--server`/`--port` skipped entirely.
    /// `ServerDirectoryRequest`/`Response` aren't opcode-encrypted, so no
    /// login/session key is needed for this.
    public static func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server] {
        let client = try await connect(
            NetworkConfig(username: "", password: "", serverAddress: address, serverPort: brokerPort, brokerPort: brokerPort)
        )
        defer { Task { await client.close() } }
        let response = try await client.request(ServerDirectoryRequest(), response: ServerDirectoryResponse.self)
        return response.directory
    }

    /// Performs the nonce + login handshake and returns the server's
    /// response (success or a specific rejection reason — see
    /// `AuthenticationStatus`).
    public func authenticate(username: String, password: String) async throws -> AuthenticationResponse {
        let nonceResponse = try await request(NonceRequest(), response: NonceResponse.self)
        let sessionKey = Key(username: username, password: password, nonce: nonceResponse.nonce)

        // `encryptedUsername` is a single raw 16-byte AES block encrypted
        // directly with the fixed login key (not the derived session key,
        // and not the opcode-checksummed packet-body scheme below) — see
        // `Key.encryptRawBlock(_:)`'s doc comment.
        var usernameWriter = ByteWriter()
        usernameWriter.write(ascii: username, fixedLength: 0x10)
        let encryptedUsername = try Key.login.encryptRawBlock(usernameWriter.bytes)

        // `encryptedData` (password + client version) is encrypted with the
        // derived session key using the normal opcode-checksummed packet
        // scheme — reuse `Packet.encrypt(key:)` by wrapping the plaintext in
        // a throwaway `Packet` under this request's own opcode, matching
        // exactly what the server decrypts it with.
        let plaintext = AuthenticationRequest.EncryptedData(password: password, clientVersion: 0)
        var dataWriter = ByteWriter()
        plaintext.encode(to: &dataWriter)
        let encryptedPacket = try Packet(opcode: .authenticationRequest, parameters: dataWriter.bytes).encrypt(key: sessionKey)

        let authenticationRequest = AuthenticationRequest(
            encryptedUsername: encryptedUsername,
            encryptedData: encryptedPacket.parameters
        )
        let response = try await request(authenticationRequest, response: AuthenticationResponse.self)
        if response.status == .success {
            self.sessionKey = sessionKey
        }
        return response
    }

    /// Confirm-connect step (State 2 → State 3 in the decompiled client):
    /// after authenticating, the client joins a channel and waits for the
    /// server's acknowledgement (opcode `0x2001`, `JoinChannelResponse`).
    /// The decompiled `State02_ServerSelect_ProcessPacket` treats a
    /// zero-status `0x2001` as "connection accepted" and transitions into
    /// that server's Game Room List — this returns the same response so the
    /// caller can check `isSuccess` before doing the equivalent transition,
    /// and hands back the initial channel roster the response carries.
    ///
    /// `channel` defaults to `0xFFFF`, the "auto-join the default channel"
    /// sentinel the real client sends when the player hasn't picked a
    /// specific channel (there's no channel-picker UI in this build, same as
    /// there's no server-row picker — see the server-list decomp notes).
    /// `joinChannelRequest`/`Response` aren't opcode-encrypted, so this
    /// needs no session key.
    public func joinChannel(_ channel: ChannelID = 0xFFFF) async throws -> JoinChannelResponse {
        try await request(JoinChannelRequest(channel: channel), response: JoinChannelResponse.self)
    }

    /// Requests the current channel's room list (outgoing opcode `0x2100`,
    /// the Game Room List's `OnEnter` room-list request in the decompiled
    /// client) and decodes the server's `0x2103` reply into its rooms.
    /// Neither opcode is encrypted, so no session key is needed.
    public func fetchRoomList(filter: RoomFilter = .all) async throws -> [RoomListResponse.Room] {
        try await request(RoomListRequest(filter: filter), response: RoomListResponse.self).rooms
    }

    /// Joins a room by ID (outgoing opcode `0x2110`) and decodes the server's
    /// `JoinRoomResponse` (`0x2111`). On success the lobby transitions into
    /// the room's Ready Room (state 9) — callers should check `isSuccess`.
    public func joinRoom(_ room: RoomID, password: RoomPassword = "") async throws -> JoinRoomResponse {
        try await request(JoinRoomRequest(room: room, password: password), response: JoinRoomResponse.self)
    }

    /// Creates a room (outgoing opcode `0x2120`) and decodes the server's
    /// `CreateRoomResponse` (`0x2121`), which carries the new room's ID. The
    /// decompiled `SendCreateRoom` sends name + password (the player-limit and
    /// mode selections aren't confirmed to go over this opcode); we send the
    /// chosen `capacity`/`settings` too since our packet models them.
    public func createRoom(
        name: String,
        password: RoomPassword = "",
        capacity: RoomCapacity,
        settings: UInt32 = 0
    ) async throws -> CreateRoomResponse {
        try await request(
            CreateRoomRequest(name: name, settings: settings, password: password, capacity: capacity),
            response: CreateRoomResponse.self
        )
    }

    /// Toggles the player's ready state in the Ready Room (opcode `0x3230` →
    /// `0x3231`). Not opcode-encrypted, so no session key is needed.
    public func setReady(_ isReady: Bool) async throws -> UserReadyResponse {
        try await request(UserReadyRequest(isReady: isReady), response: UserReadyResponse.self)
    }

    /// Selects the player's mobile/tank in the Ready Room (the character
    /// picker's `0x3200` → `0x3201`).
    public func selectTank(primary: Mobile, secondary: Mobile = .random) async throws -> RoomSelectTankResponse {
        try await request(RoomSelectTankRequest(primary: primary, secondary: secondary), response: RoomSelectTankResponse.self)
    }

    /// Changes the player's team in the Ready Room (`0x3210` → `0x3211`).
    public func selectTeam(_ team: Team) async throws -> RoomSelectTeamResponse {
        try await request(RoomSelectTeamRequest(team: team), response: RoomSelectTeamResponse.self)
    }

    /// Starts the match (host only, `0x3430`). Fire-and-forget: the server's
    /// `0x3432` start notification (a `.gameStarted` push) carries the
    /// per-player spawn data and moves everyone to Loading.
    public func startGame() async throws {
        try await send(StartGameCommand())
    }

    /// Sends in-game traffic to another player through the server's tunnel
    /// relay (`0x4500`): the payload is delivered to whoever sits in `slot`
    /// as a `.tunnelReceived` push carrying this player's slot.
    public func sendTunnel(to slot: UInt8, payload: [UInt8]) async throws {
        try await send(Tunnel(destinationSlot: slot, payload: payload))
    }

    /// Fetches the player's avatar (opcode `0x6000` → `0x6001`) — equipped
    /// bitmask + owned item IDs. The response body is a 2-byte RTC prefix
    /// followed by an AES blob (encrypted with the session key outside the
    /// normal opcode scheme), so it's decrypted here and parsed:
    /// `equipped` (u64 LE), `count` (u16 LE), then `count` item IDs (u32 LE).
    public func fetchAvatar() async throws -> PlayerAvatar {
        guard let key = sessionKey else { throw Error.notAuthenticated }
        let response = try await request(GetAvatarRequest(sendExtended: true), response: GetAvatarResponse.self)
        let bytes = response.rtcAndEncryptedData
        guard bytes.count > 2 else { return PlayerAvatar(equipped: 0, inventory: []) }
        let plaintext = [UInt8](try Crypto.AES.decrypt(Data(bytes[2...]), key: key, opcode: .getAvatarResponse))
        return Self.parseAvatar(plaintext)
    }

    /// Parses a decrypted avatar plaintext (`equipped` u64 LE, `count` u16 LE,
    /// then `count` × u32 LE item IDs). Truncated/partial data yields whatever
    /// parsed cleanly rather than throwing.
    static func parseAvatar(_ plaintext: [UInt8]) -> PlayerAvatar {
        guard plaintext.count >= 8 else { return PlayerAvatar(equipped: 0, inventory: []) }
        var equipped: UInt64 = 0
        for i in 0..<8 { equipped |= UInt64(plaintext[i]) << (8 * i) }

        var items = [UInt32]()
        if plaintext.count >= 10 {
            let count = Int(plaintext[8]) | (Int(plaintext[9]) << 8)
            var offset = 10
            for _ in 0..<count where offset + 4 <= plaintext.count {
                let id = UInt32(plaintext[offset])
                    | (UInt32(plaintext[offset + 1]) << 8)
                    | (UInt32(plaintext[offset + 2]) << 16)
                    | (UInt32(plaintext[offset + 3]) << 24)
                items.append(id)
                offset += 4
            }
        }
        return PlayerAvatar(equipped: equipped, inventory: items)
    }

    // MARK: - Sending

    /// Sends a packet without waiting for any reply — for fire-and-forget
    /// opcodes (page requests, chat, the join variants whose confirmation
    /// arrives as a push). Opcodes marked encrypted (e.g. channel chat's
    /// `0x2010`) are AES-encrypted with the session key, mirroring the
    /// server `Connection`'s write path.
    public func send<Request: GunBoundPacketEncodable>(_ requestValue: Request) async throws {
        var packet = encoder.encode(requestValue, id: 0x0000)
        if Request.opcode.isEncrypted {
            guard let key = sessionKey else { throw Error.notAuthenticated }
            packet = try packet.encrypt(key: key)
        }
        try await socket.send(Data(packet.data))
    }

    /// Sends `requestValue` and awaits the reply with `Response`'s opcode:
    /// first checking the mailbox (in case the read loop already parked it),
    /// otherwise suspending until the loop routes it in. Notifications
    /// arriving in between flow to `pushes` without disturbing the wait.
    private func request<Request: GunBoundPacketEncodable, Response: GunBoundPacketDecodable>(
        _ requestValue: Request,
        response: Response.Type
    ) async throws -> Response {
        try await send(requestValue)
        let packet = try await receivePacket(opcode: Response.opcode)
        return try decoder.decode(Response.self, from: packet)
    }

    /// The next inbound packet with `opcode` — from the mailbox if it already
    /// arrived, else by registering a waiter for the read loop to resume.
    private func receivePacket(opcode: Opcode) async throws -> Packet {
        if let index = mailbox.firstIndex(where: { $0.opcode == opcode }) {
            return mailbox.remove(at: index)
        }
        guard !isFinished else { throw Error.disconnected }
        return try await withCheckedThrowingContinuation { continuation in
            pending[opcode, default: []].append(continuation)
        }
    }
}
