//
//  GameMap.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

/// GunBound Game Map
public enum GameMap: UInt8, Codable, CaseIterable {
    
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

public extension GameMap {
    
    static let stages: [GameMap] = {
        var stages = Self.allCases
        stages.removeFirst()
        assert(stages.contains(.random) == false)
        return stages
    }()
    
    static func randomStage(using generator: inout RandomNumberGenerator) -> GameMap {
        let stage = stages.randomElement(using: &generator)!
        assert(stage != .random)
        return stage
    }
    
    static var randomStage: GameMap {
        var generator: RandomNumberGenerator = SystemRandomNumberGenerator()
        return randomStage(using: &generator)
    }
}

// MARK: - CustomStringConvertible

extension GameMap: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        switch self {
        case .random:
            return "Random"
        case .miramoTown:
            return "Miramo Town"
        case .nirvana:
            return "Nirvana"
        case .metropolis:
            return "Metropolis"
        case .seaHero:
            return "Sea Hero"
        case .adiumroot:
            return "Adiumroot"
        case .dragon:
            return "Dragon"
        case .cozytower:
            return "Cozytower"
        case .dummySlope:
            return "Dummy Slope"
        case .stardust:
            return "Stardust"
        case .metaMine:
            return "Meta Mine"
        }
    }
    
    public var debugDescription: String {
        description
    }
}
