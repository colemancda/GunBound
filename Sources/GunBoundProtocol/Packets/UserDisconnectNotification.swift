/// User Disconnect Notification
///
/// A second, companion disconnect signal alongside `UserQuitNotification`
/// — possibly distinguishing different *reasons* for a player leaving (e.g.
/// a graceful quit vs. a timeout/AFK-kick, given the bitmask-gated special
/// handling), though the exact distinction wasn't independently resolved.
/// When the payload's flags, masked with `0xf000`, are non-zero, a position
/// field and cooldown flag are also captured.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct UserDisconnectNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userDisconnectNotification }

    /// Bitmask checked against `0xf000` to decide whether position/cooldown follow.
    public let flags: UInt16

    /// Position field (tentative; only meaningful when `flags & 0xf000 != 0`).
    public let position: UInt16

    /// Cooldown flag (tentative; only meaningful when `flags & 0xf000 != 0`).
    public let cooldown: UInt8

    public init(flags: UInt16, position: UInt16 = 0, cooldown: UInt8 = 0) {
        self.flags = flags
        self.position = position
        self.cooldown = cooldown
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.flags = try UInt16(parsingLittleEndian: &input)
        self.position = try UInt16(parsingLittleEndian: &input)
        self.cooldown = try UInt8(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(flags, endianness: .little)
        output.write(position, endianness: .little)
        output.write(cooldown)
    }
}
