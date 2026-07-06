/// GunBound Packet Data Container
public struct Packet: Equatable, Hashable, Identifiable, Sendable {

    public internal(set) var data: [UInt8]

    internal init(_ data: [UInt8]) {
        self.data = data
        assert(data.count >= Packet.minSize)
    }

    public init?(data: [UInt8]) {
        self.init(data: data, validateLength: true, validateOpcode: true)
    }

    public init?(data: [UInt8], validateLength: Bool, validateOpcode: Bool) {
        // validate size
        guard data.count >= Packet.minSize,
            data.count <= Packet.maxSize
        else {
            return nil
        }
        // validate length
        if validateLength {
            let length = UInt16(littleEndian: UInt16(bytes: (data[0], data[1])))
            guard data.count == Int(length) else {
                return nil
            }
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

    public init(
        opcode: Opcode,
        id: ID = 0x00,
        parameters: [UInt8] = []
    ) {
        let length = Packet.minSize + parameters.count
        var data = [UInt8](repeating: 0, count: Packet.minSize)
        data.reserveCapacity(length)
        data += parameters
        assert(data.count == length)
        self.init(data)
        // set header bytes
        self.size = numericCast(length)
        self.id = id
        self.opcodeRawValue = opcode.rawValue
        assert(self.opcode == opcode)
    }
}

public extension Packet {

    static var minSize: Int { 6 }

    static var maxSize: Int { 1024 }
}

// MARK: - Decoding

public extension Packet {

    /// Packet size
    var size: UInt16 {
        get { UInt16(data.count) }
        set {
            let bytes = newValue.littleEndian.bytes
            data[0] = bytes.0
            data[1] = bytes.1
        }
    }

    /// Packet sequence
    var id: ID {
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

    var opcodeRawValue: UInt16 {
        get { UInt16(littleEndian: UInt16(bytes: (data[4], data[5]))) }
        set {
            let bytes = newValue.littleEndian.bytes
            data[4] = bytes.0
            data[5] = bytes.1
        }
    }

    /// Packet parameters
    var parameters: [UInt8] {
        Array(data[Self.minSize...])
    }

    var parametersSize: Int {
        data.count - Self.minSize
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

/// A `GunBoundPacket` that can be parsed from its raw parameter bytes.
public protocol GunBoundPacketDecodable: GunBoundPacket {

    init(parsing input: inout ParserSpan) throws
}

/// A `GunBoundPacket` that can encode itself into its raw parameter bytes.
public protocol GunBoundPacketEncodable: GunBoundPacket {

    func encode(to output: inout ByteWriter)
}

public extension GunBoundPacketDecodable {

    init(packet: Packet, decoder: GunBoundDecoder = GunBoundDecoder()) throws {
        self = try decoder.decode(Self.self, from: packet)
    }
}
