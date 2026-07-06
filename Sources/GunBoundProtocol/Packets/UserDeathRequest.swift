/// User Death request
public struct UserDeathRequest: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userDeadRequest }

    internal let value0: UInt8

    internal let value1: UInt32

    internal init(value0: UInt8, value1: UInt32) {
        self.value0 = value0
        self.value1 = value1
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.value0 = try UInt8(parsing: &input)
        self.value1 = try UInt32(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(value0)
        output.write(value1, endianness: .little)
    }
}
