//
//  AuthenticationRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

public struct AuthenticationRequest: GunBoundPacket, Equatable, Hashable, Codable {
    
    public static var command: Command { .authenticationRequest }
    
    
    
    public init() {
        
    }
}
