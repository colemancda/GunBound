/// GunBound Packet Decoder
public struct GunBoundDecoder: Sendable {

    /// Logging handler
    public var log: (@Sendable (String) -> Void)?

    public init() {}

    public func decodePacket<T: GunBoundPacketDecodable>(_ type: T.Type, from data: [UInt8]) throws -> T {
        guard let packet = Packet(data: data) else {
            throw GunBoundDecodingError.invalidPacket
        }
        return try decode(type, from: packet)
    }

    public func decode<T: GunBoundPacketDecodable>(_ type: T.Type, from packet: Packet) throws -> T {
        let opcode = T.opcode
        guard packet.opcode == opcode else {
            throw GunBoundDecodingError.opcodeMismatch(expected: opcode, actual: packet.opcode)
        }
        log?("Will decode \(opcode) packet")
        return try packet.parameters.withParserSpan { input in
            try T.init(parsing: &input)
        }
    }
}

public enum GunBoundDecodingError: Error, Equatable, Sendable {

    case invalidPacket
    case opcodeMismatch(expected: Opcode, actual: Opcode)
}
