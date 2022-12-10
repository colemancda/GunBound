//
//  Team.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

public enum Team: UInt8, Codable, CaseIterable {
    
    /// Team A
    case a = 0x00
    
    /// Team B
    case b = 0x01
}

// MARK: - CustomStringConvertible

extension Team: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        switch self {
        case .a:
            return "A"
        case .b:
            return "B"
        }
    }
    
    public var debugDescription: String {
        description
    }
}
