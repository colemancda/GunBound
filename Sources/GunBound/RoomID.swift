//
//  RoomID.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

public extension Room {
    
    /// GunBound Room
    struct ID: RawRepresentable, Codable, Equatable, Hashable {
        
        public var rawValue: UInt16
        
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
}

public extension Room.ID {
    
    mutating func increment() {
        if rawValue == .max {
            rawValue = .min
        } else {
            rawValue += 1
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Room.ID: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: UInt16) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Room.ID: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        rawValue.description
    }
    
    public var debugDescription: String {
        description
    }
}
