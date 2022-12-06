//
//  Packet.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation

/// GunBound Packet
public struct Packet: Equatable, Hashable, Identifiable {
    
    public let data: Data
    
    public init?(data: Data) {
        // validate size
        guard data.count >= Packet.minSize,
              data.count <= Packet.maxSize else {
            return nil
        }
        let length = UInt16(littleEndian: UInt16(bytes: (data[0], data[1])))
        guard data.count == Int(length) else {
            return nil
        }
        self.data = data
    }
}

public extension Packet {
    
    static var minSize: Int { 6 }
    
    static var maxSize: Int { 1024 }
}

// MARK - Decoding

public extension Packet {
    
    /// Packet size
    var size: UInt16 {
        UInt16(data.count)
    }
    
    /// Packet sequence
    var id: ID {
        ID(rawValue: UInt16(littleEndian: UInt16(bytes: (data[2], data[3]))))
    }
    
    /// Packet command
    var command: Command {
        Command(rawValue: UInt16(littleEndian: UInt16(bytes: (data[4], data[5]))))
    }
    
    /// Packet parameters
    var parameters: Data {
        withUnsafeParameters { Data($0) }
    }
    
    var parametersSize: Int {
        data.count - Self.minSize
    }
    
    func withUnsafeParameters<ResultType>(_ body: ((UnsafeRawBufferPointer) throws -> ResultType)) rethrows -> ResultType {
        return try data.withUnsafeBytes { pointer in
            return try body(UnsafeRawBufferPointer(start: pointer.baseAddress?.advanced(by: 6), count: parametersSize))
        }
    }
}

// MARK: - CustomStringConvertible

extension Packet: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        "Packet(size: \(size), id: \(id), command: \(command), parameters: \(parametersSize) bytes)"
    }
    
    public var debugDescription: String {
        description
    }
}
