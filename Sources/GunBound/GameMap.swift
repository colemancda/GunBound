//
//  GameMap.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

/// GunBound Game Map
public enum GameMap: UInt8, Codable {
    
    /// Random Map
    case random             = 0
    
    /// Miramo Town
    case miramoTown         = 1
    
    /// Nirvana
    case nirvana            = 2
    
    /// Metropolis
    case metropolis         = 3
    
    /// Sea of Hero
    case seaHero            = 4
    
    /// Adiumroot
    case adiumroot          = 5
    
    /// Dragon
    case dragon             = 6
    
    /// Cozytower
    case cozytower          = 7
    
    /// Dummy Slope
    case dummySlope         = 8
    
    /// Stardust
    case stardust           = 9
    
    /// Meta Mine
    case metaMine           = 10
}
