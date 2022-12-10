//
//  RoomFilter.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Filter
public enum RoomFilter: UInt8, Codable {
    
    /// All rooms
    case all = 1
    
    /// Waiting rooms
    case waiting = 2
}
