//
//  Sequence.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

public extension Packet {
    
    /// Packet sequence
    struct ID: RawRepresentable, Equatable, Hashable, Codable {
        
        public var rawValue: UInt16
        
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
}

public extension Packet.ID {
    
    mutating func increment() {
        if rawValue == .max {
            rawValue = 0
        } else {
            rawValue += 1
        }
    }
}

// MARK: - Constants

public extension Packet.ID {
    
    static var start: Packet.ID { 0xEBCB }
}

// MARK: - ExpressibleByIntegerLiteral

extension Packet.ID: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: UInt16) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension Packet.ID: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        "0x" + rawValue.toHexadecimal()
    }
    
    public var debugDescription: String {
        description
    }
}
