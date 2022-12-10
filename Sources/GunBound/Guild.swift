//
//  Guild.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

/// Guild
public struct Guild: RawRepresentable, Equatable, Hashable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    
    public let rawValue: String
    
    public init?(rawValue: String) {
        guard Self.validate(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }
}

extension Guild: FixedLengthString {
    
    public static var length: Int { 8 }
}
