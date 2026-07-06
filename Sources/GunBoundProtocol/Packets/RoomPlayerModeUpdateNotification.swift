/// Room Player Mode Update Notification
///
/// Single-byte per-slot field update — one of six fields also bulk-populated
/// by `RoomDetailResponse` (`0x2105`). This is the last opcode in the
/// systematic `0x21f2`-`0x21f7` family; a sixth per-slot field (at `+0x449ae`
/// in the original client) has no dedicated update opcode and may only ever
/// be updated via the bulk `RoomDetailResponse` path.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomPlayerModeUpdateNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomPlayerModeUpdateNotification }

    /// Reserved/unused (purpose not confirmed by static analysis).
    public let reserved: UInt16

    public let value: UInt8

    public init(reserved: UInt16 = 0, value: UInt8) {
        self.reserved = reserved
        self.value = value
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.reserved = try UInt16(parsingLittleEndian: &input)
        self.value = try UInt8(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(reserved, endianness: .little)
        output.write(value)
    }
}
