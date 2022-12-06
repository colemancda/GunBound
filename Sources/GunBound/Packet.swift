//
//  Packet.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation

/// GunBound Packet Data Container
public struct Packet: Equatable, Hashable, Identifiable {
    
    public internal(set) var data: Data
    
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
    
    internal init(command: Command) {
        self.data = Data(count: Packet.minSize)
        self.size = numericCast(Packet.minSize)
        self.command = command
    }
}

public extension Packet {
    
    static var minSize: Int { 6 }
    
    static var maxSize: Int { 1024 }
}

// MARK - Decoding

public extension Packet {
    
    /// Packet size
    internal(set) var size: UInt16 {
        get { UInt16(data.count) }
        set {
            let bytes = newValue.littleEndian.bytes
            data[0] = bytes.0
            data[1] = bytes.1
        }
    }
    
    /// Packet sequence
    internal(set) var id: ID {
        get { ID(rawValue: UInt16(littleEndian: UInt16(bytes: (data[2], data[3])))) }
        set {
            let bytes = newValue.rawValue.littleEndian.bytes
            data[2] = bytes.0
            data[3] = bytes.1
        }
    }
    
    /// Packet command
    internal(set) var command: Command {
        get { Command(rawValue: UInt16(littleEndian: UInt16(bytes: (data[4], data[5])))) }
        set {
            let bytes = newValue.rawValue.littleEndian.bytes
            data[4] = bytes.0
            data[5] = bytes.1
        }
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
            let parametersPointer = pointer.count > 6 ? pointer.baseAddress?.advanced(by: 6) : nil
            return try body(UnsafeRawBufferPointer(start: parametersPointer, count: parametersSize))
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

// MARK: -

/// Gunbound Packet Parameters protocol
public protocol GunBoundPacket {
    
    /// GunBound command type
    static var command: Command { get }
}

internal protocol GunBoundPacketEncodable: GunBoundPacket, Encodable {
    
    var expectedLength: Int { get }
}
