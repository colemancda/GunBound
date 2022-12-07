//
//  FAuthenticationResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

/// Authentication Response
public struct AuthenticationResponse: GunBoundPacket, Encodable, Hashable {
    
    public static var opcode: Opcode { .authenticationResponse }
    
    public let status: AuthenticationStatus
    
    public let profile: Profile?
}

// MARK: - Supporting Types

public extension AuthenticationResponse {
    
    struct Profile: Encodable, Hashable {
        
        
    }
}
