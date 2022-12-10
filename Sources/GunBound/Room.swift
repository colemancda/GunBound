//
//  Room.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// GunBound Room
public struct Room: Equatable, Hashable, Encodable, Identifiable {
    
    public let id: ID
    
    public var name: String
    
    public var password: RoomPassword
    
    public var map: GameMap
    
    public var settings: UInt32
    
    public var players: Set<String>
    
    public var playerCapacity: RoomCapacity
    
    public var isPlaying: Bool
    
    public var isLocked: Bool
}
