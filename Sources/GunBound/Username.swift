//
//  Username.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

/// Username
public struct Username: RawRepresentable, Equatable, Hashable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    
    public let rawValue: String
    
    public init?(rawValue: String) {
        guard Self.validate(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }
}

// MARK: - FixedLengthString

extension Username: FixedLengthString {
    
    public static var length: Int { 0xC }
}

// MARK: - Comparable

extension Username: Comparable {
    
    public static func < (lhs: Username, rhs: Username) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public static func > (lhs: Username, rhs: Username) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
}
