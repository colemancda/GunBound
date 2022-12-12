//
//  Channel.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

public extension Channel {
    
    /// GunBound Channel
    struct UserID: RawRepresentable, Codable, Equatable, Hashable {
        
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

public extension Channel.UserID {
    
    static var min: Channel.UserID { Channel.UserID(rawValue: .min) }
    
    static var max: Channel.UserID { Channel.UserID(rawValue: .max) }
}

// MARK: - Comparable

extension Channel.UserID: Comparable {
    
    public static func < (lhs: Channel.UserID, rhs: Channel.UserID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public static func > (lhs: Channel.UserID, rhs: Channel.UserID) -> Bool {
        lhs.rawValue > rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Channel.UserID: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: UInt8) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Channel.UserID: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        rawValue.description
    }
    
    public var debugDescription: String {
        description
    }
}

