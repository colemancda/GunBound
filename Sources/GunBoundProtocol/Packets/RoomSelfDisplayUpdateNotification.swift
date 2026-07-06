/// Room Self Display Update Notification
///
/// Companion write path to `RoomDetailResponse`'s (`0x2105`) 128-byte
/// per-slot display buffer, used when the client itself is the subject of
/// the update (the server resolves "my own slot" rather than supplying a
/// slot index the client would look up).
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomSelfDisplayUpdateNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomSelfDisplayUpdateNotification }

    /// Reserved/unused (purpose not confirmed by static analysis).
    public let reserved: UInt16

    public let displayBuffer: String

    public init(reserved: UInt16 = 0, displayBuffer: String) {
        self.reserved = reserved
        self.displayBuffer = displayBuffer
    }

    public init(parsing input: inout ParserSpan) throws {
        self.reserved = try UInt16(parsingLittleEndian: &input)
        self.displayBuffer = try String(parsingLengthPrefixedASCII: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(reserved, endianness: .little)
        output.writeLengthPrefixed(ascii: displayBuffer)
    }
}
