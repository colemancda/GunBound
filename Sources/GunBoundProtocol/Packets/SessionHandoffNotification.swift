/// Session/Server Handoff Notification
///
/// Sent by the server right after channel/server selection. Two `uint`
/// fields are stored by the client into session-scoped globals; likely a
/// session token or server address handoff. The exact meaning of the two
/// fields (session ID? server IP?) was not individually disambiguated.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct SessionHandoffNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .sessionHandoffNotification }

    public let value0: UInt32

    public let value1: UInt32

    public init(value0: UInt32, value1: UInt32) {
        self.value0 = value0
        self.value1 = value1
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.value0 = try UInt32(parsingLittleEndian: &input)
        self.value1 = try UInt32(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(value0, endianness: .little)
        output.write(value1, endianness: .little)
    }
}
