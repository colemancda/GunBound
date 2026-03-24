/// Sell Avatar Item Request (0x6020) — encrypted
public struct SellRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .sellRequest }

    /// Inventory slot index of the item to sell.
    public let itemPosition: UInt8

    /// Extended (DWORD) avatar item code.
    public let avatar: UInt32

    public init(from container: GunBoundDecodingContainer) throws {
        itemPosition = try container.decode(UInt8.self)
        avatar = try container.decode(UInt32.self)
    }
}
