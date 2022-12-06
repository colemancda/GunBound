//
//  Command.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation

/// Gunbound Packet Command
public struct Command: RawRepresentable, Equatable, Hashable, Codable {
    
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Command: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: UInt16) {
        self.init(rawValue: value)
    }
}

// MARK: - Command

extension Command: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        "0x" + rawValue.toHexadecimal()
    }
    
    public var debugDescription: String {
        description
    }
}

// MARK: - Definitions

public extension Command {
    
    /// Authentication Request
    static var authenticationRequest: Command { 0x1310 }
    
    /// Authentication Response
    static var authenticationResponse: Command { 0x1312 }
    
    /// Server Directory Request
    static var serverDirectoryRequest: Command { 0x1100 }
    
    /// Server Directory Response
    static var serverDirectoryResponse: Command { 0x1102 }
}
