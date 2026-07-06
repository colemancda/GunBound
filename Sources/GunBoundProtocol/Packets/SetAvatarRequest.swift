/// Set Avatar (Equip) Request
///
/// Sent by the client to equip avatar items.
/// Updates the player's equipped avatar configuration.
///
/// **Opcode:** 0x6004
///
/// **Usage:**
/// Used when a player wants to change their equipped avatar items.
/// The avatarEquipped field is a bitmask representing which items
/// are equipped in each slot (head, body, eye, flag).
///
/// **Note:** This packet is encrypted and requires decryption before processing.
public struct SetAvatarRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Sendable {

    public static var opcode: Opcode { .setAvatarRequest }

    /// 8-byte equipped avatar bitmask (4 x WORD slots: head, body, eye, flag)
    public let avatarEquipped: UInt64

    public init(avatarEquipped: UInt64) {
        self.avatarEquipped = avatarEquipped
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        avatarEquipped = try UInt64(parsingBigEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(avatarEquipped, endianness: .big)
    }
}
