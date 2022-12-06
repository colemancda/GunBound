//
//  Nonce.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

/// GunBound Cryptographic Nonce
public struct Nonce: RawRepresentable, Equatable, Hashable, Codable {
    
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public extension Nonce {
    
    /// Initialize `Nonce` with random value.
    init() {
        let randomValue = UInt32.random(in: .min ..< .max)
        self.init(rawValue: randomValue)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Nonce: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: UInt32) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension Nonce: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        "0x" + rawValue.toHexadecimal()
    }
    
    public var debugDescription: String {
        description
    }
}
