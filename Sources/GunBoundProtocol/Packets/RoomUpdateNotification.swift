/// Room Update Notification
///
/// Broadcast by server when room state changes.
/// Notifies all players in the room about updates.
///
/// **Usage:**
/// Sent when:
/// - Room settings change (map, capacity, options)
/// - Player changes team or mobile
/// - Room title changes
/// - Game starts or ends
///
/// Players should refresh their room display when receiving this packet.
public struct RoomUpdateNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomUpdateNotification }

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
