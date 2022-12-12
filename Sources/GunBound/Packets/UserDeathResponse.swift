//
//  UserDeathResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// User Death response
public struct UserDeathResponse: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .userDeadResponse }
    
    public init() { }
}
