/// Room Return Result Response
///
/// Sent by the server in response to RoomReturnResultRequest.
/// Confirms game result processing and return to lobby.
///
/// **Usage:**
/// Sent after processing game results when players return to the lobby.
/// The server has calculated all player statistics, awarded gold and XP,
/// and updated player records.
///
/// After receiving this, the client should:
/// - Return to the lobby interface
/// - Update player statistics display
/// - Show any reward notifications
///
/// The RTC field indicates success (0x0000) or error codes.
public struct RoomReturnResultResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomReturnResultResponse }

    /// Return code (0x0000 = success, non-zero = error)
    internal let rtc: UInt16

    public init() {
        self.rtc = 0x0000
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.rtc = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rtc, endianness: .little)
    }
}
