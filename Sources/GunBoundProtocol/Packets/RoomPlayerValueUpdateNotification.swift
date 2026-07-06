/// Room Player Value Update Notification
///
/// 4-byte per-slot field update — one of six fields also bulk-populated by
/// `RoomDetailResponse` (`0x2105`).
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomPlayerValueUpdateNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomPlayerValueUpdateNotification }

    /// Reserved/unused (purpose not confirmed by static analysis).
    public let reserved: UInt16

    public let value: UInt32

    public init(reserved: UInt16 = 0, value: UInt32) {
        self.reserved = reserved
        self.value = value
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.reserved = try UInt16(parsingLittleEndian: &input)
        self.value = try UInt32(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(reserved, endianness: .little)
        output.write(value, endianness: .little)
    }
}
