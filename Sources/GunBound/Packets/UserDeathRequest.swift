//
//  UserDeathRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// User Death request
public struct UserDeathRequest: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .userDeadRequest }
    
    internal let value0: UInt8
    
    internal let value1: UInt32
}
