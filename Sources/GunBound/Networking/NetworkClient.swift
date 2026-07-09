import Foundation
import GunBoundProtocol

/// A minimal client-side connection to a GunBound world server: opens a TCP
/// socket and performs the nonce + login handshake
/// (`NonceRequest`/`NonceResponse` → `AuthenticationRequest`/
/// `AuthenticationResponse`). Deliberately not a full port of the server's
/// internal `Connection` actor (that type is `internal` to the `GunBound`
/// target and reused for the accept-side loop, request/response matching,
/// and outgoing-encryption bookkeeping this client doesn't need yet) — this
/// is just enough to prove out real network authentication before building
/// out the rest of the post-login protocol (room list, chat, etc).
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
    }

    private let socket: Socket

    private let encoder = GunBoundEncoder()

    private let decoder = GunBoundDecoder()

    /// Set once `authenticate(username:password:)` succeeds — every
    /// opcode marked `isEncrypted` after login needs this to
    /// encrypt/decrypt its packet body, mirroring `Connection.key`.
    public private(set) var sessionKey: Key?

    private init(socket: Socket) {
        self.socket = socket
    }

    /// Opens a TCP connection to `config.serverAddress`:`config.serverPort`.
    public static func connect(_ config: NetworkConfig) async throws -> NetworkClient<Socket> {
        guard let destination = GunBoundAddress(address: config.serverAddress, port: config.serverPort) else {
            throw Error.invalidAddress(config.serverAddress)
        }
        guard let local = GunBoundAddress(address: "0.0.0.0", port: 0) else {
            throw Error.invalidAddress("0.0.0.0")
        }
        let socket = try await Socket.client(address: local, destination: destination)
        return NetworkClient(socket: socket)
    }

    public func close() async {
        await socket.close()
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

    /// Sends `requestValue` and decodes the next packet read off the socket
    /// as `Response`. No request/response ID matching or queueing (unlike
    /// `Connection`) — fine for the strictly-sequential login handshake this
    /// is used for today.
    private func request<Request: GunBoundPacketEncodable, Response: GunBoundPacketDecodable>(
        _ requestValue: Request,
        response: Response.Type
    ) async throws -> Response {
        let packet = encoder.encode(requestValue, id: 0x0000)
        try await socket.send(Data(packet.data))
        let data = try await socket.recieve(Packet.maxSize)
        return try decoder.decodePacket(Response.self, from: [UInt8](data))
    }
}
