//
//  GameMode.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Client state
public struct GameMode: RawRepresentable, Equatable, Hashable, Codable {
    
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension GameMode: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: RawValue) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension GameMode: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        switch self {
        case .introSplash:
            return "Intro Splash"
        case .worldSelect:
            return "World Select"
        case .channel:
            return "Channel"
        case .init3d:
            return "Init3D/Evangelion failed"
        case .avatarShop:
            return "Avatar Shop"
        case .room:
            return "Room"
        case .inGameSession:
            return "In Game Session"
        case .exitToDesktop:
            return "Exit to Desktop"
        default:
            return "0x" + rawValue.toHexadecimal()
        }
    }
    
    public var debugDescription: String {
        description
    }
}

// MARK: - Definitions

public extension GameMode {
    
    /// Intro splash
    static var introSplash: GameMode     { 1 }
    static var worldSelect: GameMode     { 2 }
    static var channel: GameMode         { 3 }
    static var init3d: GameMode          { 5 }
    static var avatarShop: GameMode      { 7 }
    static var room: GameMode            { 9 }
    static var inGameSession: GameMode   { 11 }
    static var exitToDesktop: GameMode   { 15 }
}
