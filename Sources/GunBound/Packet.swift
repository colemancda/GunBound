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
        self.init(data: data, validateOpcode: true)
    }
    
    internal init?(data: Data, validateOpcode: Bool) {
        // validate size
        guard data.count >= Packet.minSize,
              data.count <= Packet.maxSize else {
            return nil
        }
        // validate length
        let length = UInt16(littleEndian: UInt16(bytes: (data[0], data[1])))
        guard data.count == Int(length) else {
            return nil
        }
        self.data = data
        // validate opcode
        if validateOpcode {
            guard let opcode = Opcode(rawValue: self.opcodeRawValue) else {
                return nil
            }
            assert(self.opcode == opcode)
        }
    }
    
    internal init(opcode: Opcode) {
        self.data = Data(count: Packet.minSize)
        self.size = numericCast(Packet.minSize)
        self.opcodeRawValue = opcode.rawValue
        assert(self.opcode == opcode)
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
    var opcode: Opcode {
        guard let opcode = Opcode(rawValue: opcodeRawValue) else {
            fatalError("Invalid opcode \(opcodeRawValue.toHexadecimal())")
        }
        return opcode
    }
    
    internal var opcodeRawValue: UInt16 {
        get { UInt16(littleEndian: UInt16(bytes: (data[4], data[5]))) }
        set {
            let bytes = newValue.littleEndian.bytes
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
        "Packet(size: \(size), id: \(id), opcode: \(opcode), parameters: \(parametersSize) bytes)"
    }
    
    public var debugDescription: String {
        description
    }
}

// MARK: - Supporting Types

/// Gunbound Packet Parameters protocol
public protocol GunBoundPacket {
    
    /// GunBound command type
    static var opcode: Opcode { get }
}

internal protocol GunBoundPacketEncodable: GunBoundPacket, Encodable {
    
    var expectedLength: Int { get }
}

internal extension GunBoundPacket where Self: Decodable {
    
    init(packet: Packet, decoder: GunBoundDecoder = GunBoundDecoder()) throws {
        self = try decoder.decode(Self.self, from: packet)
    }
}
