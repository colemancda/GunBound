//
//  AuthenticationRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// GunBound Authentication Request
public struct AuthenticationRequest: GunBoundPacket, Equatable, Hashable, Decodable {
    
    public static var opcode: Opcode { .authenticationRequest }
    
    public let username: String
    
    /// Needs to be decrypted before it can be decoded
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
        let _ = try container.decode(Data.self, length: 0x10) // unknown
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
