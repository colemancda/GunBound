//
//  AuthenticationRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

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
public struct AuthenticationRequest: GunBoundPacket, Equatable, Hashable, Decodable {

    public static var opcode: Opcode { .authenticationRequest }

    /// The player's username (16 bytes, AES-encrypted with login key)
    public let username: String

    /// Encrypted payload containing password and client version
    ///
    /// This data must be decrypted using the server's decryption key
    /// before it can be decoded. It contains:
    /// - Password (12 bytes)
    /// - Padding (8 bytes)
    /// - Client version (4 bytes)
    public let encryptedData: Data
}

// MARK: - GunBoundDecodable

extension AuthenticationRequest: GunBoundDecodable {

    public init(from container: GunBoundDecodingContainer) throws {
        // decode username
        self.username = try container.decode(length: 0x10) {
            let decryptedData = try Crypto.AES.decrypt($0, key: .login)
            return decryptedData.withUnsafeBytes {
                $0.baseAddress?.withMemoryRebound(to: Int8.self, capacity: decryptedData.count) {
                    return String(cString: $0, encoding: .ascii)
                }
            }
        }
        let _ = try container.decode(Data.self, length: 0x10)  // unknown
        // starts at 0x20
        assert(container.decoder.offset == 6 + 0x20)
        self.encryptedData = try container.decode(Data.self, length: container.remainingBytes)
    }
}

// MARK: - Supporting Types

public extension AuthenticationRequest {

    /// Encrupted payload for authentication request.
    struct EncryptedData: Decodable, Equatable, Hashable {

        public let password: String

        public let clientVersion: ClientVersion
    }
}

extension AuthenticationRequest.EncryptedData: GunBoundDecodable {

    public init(from container: GunBoundDecodingContainer) throws {
        // decode password
        self.password = try container.decode(length: 0xC) { data in
            data.withUnsafeBytes {
                $0.baseAddress?.withMemoryRebound(to: Int8.self, capacity: data.count) {
                    return String(cString: $0, encoding: .ascii)
                }
            }
        }
        // padding?
        let _ = try container.decode(Data.self, length: 0x14 - 0xC)
        // decode client version
        self.clientVersion = try container.decode(ClientVersion.self, forKey: AuthenticationRequest.EncryptedData.CodingKeys.clientVersion)
    }
}
