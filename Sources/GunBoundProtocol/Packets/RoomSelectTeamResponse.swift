/// Room Select Team Response
/// Server response to team selection request.
public struct RoomSelectTeamResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomSelectTeamResponse }

    /// Return code (0x00 = success)
    public let rtc: UInt16

    public init() {
        self.rtc = 0x00
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.rtc = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rtc, endianness: .little)
    }
}
