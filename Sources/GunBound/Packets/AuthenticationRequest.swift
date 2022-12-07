//
//  AuthenticationRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

public struct AuthenticationRequest: GunBoundPacket, Equatable, Hashable, Decodable {
    
    public static var opcode: Opcode { .authenticationRequest }
    
    public let username: String
}

extension AuthenticationRequest: GunBoundDecodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        // decode username
        self.username = try container.decode(length: 0x10) {
            let decryptedData = try Crypto.AES.decrypt($0, key: .login)
            return String(data: decryptedData, encoding: .ascii)
        }
    }
}
