/// User Death response
public struct UserDeathResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userDeadResponse }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
