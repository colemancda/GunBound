/// GunBound Authentication Request
///
/// Sent by the client to authenticate with the GunBound server.
/// This packet contains the username and encrypted authentication data
/// (password and client version) used to verify the user's identity.
///
/// **Structure:**
/// - Username (16 bytes, AES-encrypted)
/// - Unknown data (16 bytes)
/// - Encrypted data payload (variable length, contains password and client version)
///
/// **Usage:**
/// This is the first packet sent by the client after connecting to the server.
/// The server must decrypt the username and encrypted data to validate credentials.
///
/// Encryption/decryption (AES, via CryptoSwift) is not available in this
/// Foundation-free module — callers encrypt/decrypt `encryptedUsername`/
/// `encryptedData` themselves, using `Username(parsing:)`/`.encode(to:)` and
/// `EncryptedData(parsing:)`/`.encode(to:)` on the plaintext bytes before
/// encrypting or after decrypting.
public struct AuthenticationRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .authenticationRequest }

    /// The player's username (16 bytes, AES-encrypted with login key)
    public let encryptedUsername: [UInt8]

    /// Unknown 16-byte block (purpose not confirmed; preserved as-is for
    /// round-trip fidelity rather than assumed to be zero/padding).
    public let unknown: [UInt8]

    /// Encrypted payload containing password and client version
    ///
    /// This data must be decrypted using the server's decryption key
    /// before it can be decoded. It contains:
    /// - Password (12 bytes)
    /// - Padding (8 bytes)
    /// - Client version (4 bytes)
    public let encryptedData: [UInt8]

    public init(encryptedUsername: [UInt8], unknown: [UInt8] = [UInt8](repeating: 0, count: 0x10), encryptedData: [UInt8]) {
        self.encryptedUsername = encryptedUsername
        self.unknown = unknown
        self.encryptedData = encryptedData
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.encryptedUsername = try [UInt8](parsing: &input, byteCount: 0x10)
        self.unknown = try [UInt8](parsing: &input, byteCount: 0x10)
        self.encryptedData = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(encryptedUsername)
        output.write(unknown)
        output.write(encryptedData)
    }
}

// MARK: - Supporting Types

public extension AuthenticationRequest {

    /// Encrypted payload for authentication request.
    struct EncryptedData: Equatable, Hashable, Sendable {

        public let password: String

        public let clientVersion: ClientVersion

        public init(password: String, clientVersion: ClientVersion) {
            self.password = password
            self.clientVersion = clientVersion
        }
    }
}

extension AuthenticationRequest.EncryptedData {

    public init(parsing input: inout ParserSpan) throws {
        self.password = try String(parsingFixedLengthASCII: &input, length: 0xC)
        // padding?
        _ = try [UInt8](parsing: &input, byteCount: 0x14 - 0xC)
        self.clientVersion = try ClientVersion(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(ascii: password, fixedLength: 0xC)
        output.write([UInt8](repeating: 0, count: 0x14 - 0xC))
        clientVersion.encode(to: &output)
    }
}
