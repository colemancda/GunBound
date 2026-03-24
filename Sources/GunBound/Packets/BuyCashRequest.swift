/// Buy Avatar with Cash Request (0x6011) — encrypted
public struct BuyCashRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .buyCashRequest }

    /// Extended (DWORD) avatar item code.
    public let avatar: UInt32

    public init(from container: GunBoundDecodingContainer) throws {
        avatar = try container.decode(UInt32.self)
    }
}
