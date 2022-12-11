//
//  Channel.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

public extension Channel {
    
    /// GunBound Channel
    struct ID: RawRepresentable, Codable, Equatable, Hashable {
        
        public var rawValue: UInt16
        
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Channel.ID: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: UInt16) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Channel.ID: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        rawValue.description
    }
    
    public var debugDescription: String {
        description
    }
}
