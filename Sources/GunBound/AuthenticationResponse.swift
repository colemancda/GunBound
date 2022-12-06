//
//  FAuthenticationResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

/// Authentication Response
public enum AuthenticationResponse: UInt16, Codable {
    
    case success = 0x0000
    case badUsername = 0x0010
    case badPassword = 0x0011
    case bannedUser = 0x0030
    case badVersion = 0x0060
}
