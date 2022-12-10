//
//  RoomChangeCapacityCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

/// Room Change Option Command
public struct RoomChangeCapacityCommand: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomChangeCapacityCommand }
    
    public var capacity: RoomCapacity
}
