//
//  RoomChangeOptionCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Change Option Command
public struct RoomChangeOptionCommand: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomChangeOptionCommand }
    
    public var settings: UInt32
}
