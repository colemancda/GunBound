/// Set Avatar (Equip) Request (0x6004) — encrypted
public struct SetAvatarRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .setAvatarRequest }

    /// 8-byte equipped avatar bitmask (4 x WORD slots: head, body, eye, flag).
    public let avatarEquipped: UInt64

    public init(from container: GunBoundDecodingContainer) throws {
        avatarEquipped = try container.decode(UInt64.self)
    }
}
