//
//  GameResultCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Game Result Command
public struct GameResultCommand: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .playResultCommand }
    
    
}
