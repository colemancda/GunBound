/// Buy Avatar with Gold Request
///
/// Sent by the client to purchase avatar items using gold (in-game currency).
/// This packet is encrypted and contains the avatar item code to be purchased.
///
/// **Opcode:** 0x6010
///
/// **Usage:**
/// Used in the shop interface when buying avatar items with gold.
/// The avatar ID corresponds to the extended item code in the shop catalog.
/// The server verifies the purchase and deducts gold from the player's account.
///
/// **Note:** This packet is encrypted and requires decryption before processing.
public struct BuyGoldRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .buyGoldRequest }

    /// Extended (DWORD) avatar item code from the shop catalog
    public let avatar: UInt32

    public init(from container: GunBoundDecodingContainer) throws {
        avatar = try container.decode(UInt32.self)
    }
}
