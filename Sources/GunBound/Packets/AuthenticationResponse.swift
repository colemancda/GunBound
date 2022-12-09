//
//  AuthenticationResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Authentication Response
public struct AuthenticationResponse: GunBoundPacket, Encodable, Hashable {
    
    public static var opcode: Opcode { .authenticationResponse }
    
    public let status: AuthenticationStatus
    
    public let encryptedData: Data?
}

public extension AuthenticationResponse {
    
    static var badUsername: AuthenticationResponse {
        AuthenticationResponse(status: .badUsername, encryptedData: nil)
    }
    
    static var badPassword: AuthenticationResponse {
        AuthenticationResponse(status: .badPassword, encryptedData: nil)
    }
    
    static var bannedUser: AuthenticationResponse {
        AuthenticationResponse(status: .bannedUser, encryptedData: nil)
    }
    
    static var badVersion: AuthenticationResponse {
        AuthenticationResponse(status: .badVersion, encryptedData: nil)
    }
    
    init(user: User, key: Key, encoder: GunBoundEncoder = GunBoundEncoder()) throws {
        self.init(status: .success, encryptedData: Data())
    }
}

// MARK: - Supporting Types

public extension AuthenticationResponse {
    
    struct EncryptedData: Encodable, Hashable {
        
        public let gold: UInt16
    }
}
