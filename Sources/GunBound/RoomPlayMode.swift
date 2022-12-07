//
//  RoomPlayMode.swift
//  
//
//  Created by Alsey Coleman Miller on 12/7/22.
//

/// GunBound Room Play mode
public enum RoomPlayMode: UInt8, Codable {
    
    /// Solo
    case solo       = 0x00
    
    /// Score
    case score      = 0x44
    
    /// Tag
    case tag        = 0x08
    
    /// Jewel
    case jewel      = 0x0C
}
