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
    
    public var map: GameMap
    
    public var settings: UInt32
    
    public var playerCount: UInt8
    
    public var playerCapacity: UInt8
    
    public var isPlaying: Bool
    
    public var isLocked: Bool
}
