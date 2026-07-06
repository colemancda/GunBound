/// Room Detail Response
///
/// Broadcasts one player's info/profile (name plus a handful of stat bytes)
/// to be displayed in that player's row of the room list — copied into the
/// same 128-byte per-slot display buffer that `RoomSelfDisplayUpdateNotification`
/// (`0x21f0`) writes via a different ("find my own slot") trigger path.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomDetailResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomDetailResponse }

    /// Reserved/unused (purpose not confirmed by static analysis).
    public let reserved: UInt16

    public let name: String

    /// Trailing stat fields of unconfirmed shape.
    public let extra: [UInt8]

    public init(reserved: UInt16 = 0, name: String, extra: [UInt8] = []) {
        self.reserved = reserved
        self.name = name
        self.extra = extra
    }

    public init(parsing input: inout ParserSpan) throws {
        self.reserved = try UInt16(parsingLittleEndian: &input)
        self.name = try String(parsingLengthPrefixedASCII: &input)
        self.extra = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(reserved, endianness: .little)
        output.writeLengthPrefixed(ascii: name)
        output.write(extra)
    }
}
