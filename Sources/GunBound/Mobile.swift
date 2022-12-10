//
//  Mobile.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

/// GunBound Mobile / Tanks
public enum Mobile: UInt8, Codable, CaseIterable {
    
    /// Armor
    case armor      = 0x00
    
    /// Mage
    case mage       = 0x01
    
    /// Nak
    case nak        = 0x02
    
    /// Trico
    case trico      = 0x03
    
    /// Big Foot
    case bigFoot    = 0x04
    
    /// Boomer
    case boomer     = 0x05
    
    /// Raon
    case raon       = 0x06
    
    /// Lighting
    case lightning  = 0x07
    
    /// J.D
    case jd         = 0x08
    
    /// A.Sate
    case asate      = 0x09
    
    /// Ice
    case ice        = 0x0A
    
    /// Turtle
    case turtle     = 0x0B
    
    /// Grub
    case grub       = 0x0C
    
    /// Aduka
    case aduka      = 0x0D
    
    /// Dragon
    case dragon     = 0x11
    
    /// Knight
    case knight     = 0x12
    
    /// Random
    case random     = 0xFF
}

// MARK: - CustomStringConvertible

extension Mobile: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        switch self {
        case .random:
            return "Random"
        case .armor:
            return "Armor Mobile"
        case .mage:
            return "Mage"
        case .nak:
            return "Nakmachine"
        case .trico:
            return "Trico"
        case .bigFoot:
            return "Big Foot"
        case .boomer:
            return "Boomer"
        case .raon:
            return "Raon Launcher"
        case .lightning:
            return "Lighting"
        case .jd:
            return "J.D"
        case .asate:
            return "A.Sate"
        case .ice:
            return "Ice"
        case .turtle:
            return "Turtle"
        case .grub:
            return "Grub"
        case .aduka:
            return "Aduka"
        case .dragon:
            return "Dragon"
        case .knight:
            return "Knight"
        }
    }
    
    public var debugDescription: String {
        description
    }
}
