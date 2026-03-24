/// Buy Avatar with Gold Request (0x6010) — encrypted
public struct BuyGoldRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .buyGoldRequest }

    /// Extended (DWORD) avatar item code.
    public let avatar: UInt32

    public init(from container: GunBoundDecodingContainer) throws {
        avatar = try container.decode(UInt32.self)
    }
}
