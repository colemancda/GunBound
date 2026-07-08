import Foundation
import GunBound
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
public actor NetworkClient {

    public enum Error: Swift.Error, Equatable {
        case invalidAddress(String)
    }

    private let socket: GunBoundSocketIPv4TCP

    private let encoder = GunBoundEncoder()

    private let decoder = GunBoundDecoder()

    /// Set once `authenticate(username:password:)` succeeds — every
    /// opcode marked `isEncrypted` after login needs this to
    /// encrypt/decrypt its packet body, mirroring `Connection.key`.
    public private(set) var sessionKey: Key?

    private init(socket: GunBoundSocketIPv4TCP) {
        self.socket = socket
    }

    /// Opens a TCP connection to `config.serverAddress`:`config.serverPort`.
    public static func connect(_ config: NetworkConfig) async throws -> NetworkClient {
        guard let destination = GunBound.GunBoundAddress(address: config.serverAddress, port: config.serverPort) else {
            throw Error.invalidAddress(config.serverAddress)
        }
        guard let local = GunBound.GunBoundAddress(address: "0.0.0.0", port: 0) else {
            throw Error.invalidAddress("0.0.0.0")
        }
        let socket = try await GunBoundSocketIPv4TCP.client(address: local, destination: destination)
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
