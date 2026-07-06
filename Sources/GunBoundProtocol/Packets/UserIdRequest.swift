/// User ID Request
/// Request to look up another user's information by username
public struct UserIdRequest: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userRequest }

    public var unknown: UInt16
    public var username: Username

    public init(unknown: UInt16 = 0, username: Username) {
        self.unknown = unknown
        self.username = username
    }

    public init(parsing input: inout ParserSpan) throws {
        self.unknown = try UInt16(parsingLittleEndian: &input)
        self.username = try Username(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(unknown, endianness: .little)
        username.encode(to: &output)
    }
}
