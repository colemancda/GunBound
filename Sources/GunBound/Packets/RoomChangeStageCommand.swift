//
//  RoomChangeStageCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Change Map Command
public struct RoomChangeStageCommand: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomChangeStageCommand }
    
    public var map: GameMap
}
