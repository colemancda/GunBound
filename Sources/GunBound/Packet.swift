//
//  Packet.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation

/// GunBound Packet
public struct Packet {
    
    public let data: Data
    
    public init?(data: Data) {
        // validate size
        guard data.count >= Packet.minSize,
              data.count <= Packet.maxSize else {
            return nil
        }
        self.data = data
    }
}

public extension Packet {
    
    static var minSize: Int { 6 }
    
    static var maxSize: Int { 1024 }
}
/*
public extension Packet {
    
    /// Packet size
    var size: UInt16 {
        UInt16(parameters.count)
    }
    
    /// Packet sequence
    var sequence: UInt16 {
        
    }
    
    /// Packet command
    var command: Command {
        
    }
    
    /// Packet parameters
    var parameters: Data {
        withParameters { Data($0) }
    }
    
    func withParameters<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        try data.withUnsafeBytes { pointer in
            try body(pointer.advanced(by: 6))
        }
    }
}

// MARK: - CustomStringConvertible

extension Packet: CustomStringConvertible {
    
    
}
*/
