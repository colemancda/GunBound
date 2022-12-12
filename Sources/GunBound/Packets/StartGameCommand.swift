//
//  StartGameCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Start Game command
public struct StartGameCommand: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .startGameCommand }
    
    internal let value0: UInt32
}
