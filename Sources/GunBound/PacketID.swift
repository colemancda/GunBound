//
//  PacketID.swift
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
    
    init(sumPacketLength: Int) {
        let intermediate = (sumPacketLength * 0x43FD) & 0xFFFF
        let value = (intermediate - 0x53FD) & 0xFFFF
        self.init(rawValue: UInt16(value))
    }
}

// MARK: - Constants

public extension Packet.ID {
    
    /// First login packet is special
    static var login: Packet.ID { 0xEBCB }
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
