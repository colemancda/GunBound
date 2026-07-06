/// Client Command Grade Limit (`SVC_CMD_GRADELIMIT`)
///
/// Sent by the server to push the accepted rank/grade range (mirrors
/// `InMemoryGunBoundServerDataSource.State.gradeLimitFirst`/`gradeLimitLast`).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandGradeLimit: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandGradeLimit }

    public let gradeLimitFirst: Int16

    public let gradeLimitLast: Int16

    public init(gradeLimitFirst: Int16, gradeLimitLast: Int16) {
        self.gradeLimitFirst = gradeLimitFirst
        self.gradeLimitLast = gradeLimitLast
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.gradeLimitFirst = try Int16(parsingLittleEndian: &input)
        self.gradeLimitLast = try Int16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(gradeLimitFirst, endianness: .little)
        output.write(gradeLimitLast, endianness: .little)
    }
}
