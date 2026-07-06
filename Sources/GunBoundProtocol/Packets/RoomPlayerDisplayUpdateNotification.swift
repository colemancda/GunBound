/// Room Player Display Update Notification
///
/// Per-field update to another player's 128-byte display buffer (see
/// `RoomSelfDisplayUpdateNotification` for the "self" counterpart).
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomPlayerDisplayUpdateNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomPlayerDisplayUpdateNotification }

    /// Reserved/unused (purpose not confirmed by static analysis).
    public let reserved: UInt16

    public let displayBuffer: [UInt8]

    public init(reserved: UInt16 = 0, displayBuffer: [UInt8]) {
        self.reserved = reserved
        self.displayBuffer = displayBuffer
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.reserved = try UInt16(parsingLittleEndian: &input)
        self.displayBuffer = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(reserved, endianness: .little)
        output.write(displayBuffer)
    }
}
