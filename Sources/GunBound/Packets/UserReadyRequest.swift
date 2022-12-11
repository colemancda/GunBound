//
//  UserReadyRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

/// User Ready request
public struct UserReadyRequest: GunBoundPacket, Equatable, Hashable, Codable {
    
    public static var opcode: Opcode { .roomUserReadyRequest }
    
    public var isReady: Bool
    
    public init(isReady: Bool) {
        self.isReady = isReady
    }
}
