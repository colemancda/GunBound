/// Sell Avatar Item Request
///
/// Sent by the client to sell an avatar item back to the shop.
/// The item is removed from inventory and gold is credited.
///
/// **Opcode:** 0x6020
///
/// **Usage:**
/// Used when a player wants to sell an avatar item from their inventory.
/// The server validates the request, removes the item, and credits the player
/// with gold based on the item's sell price.
///
/// **Note:** This packet is encrypted and requires decryption before processing.
public struct SellRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Sendable {

    public static var opcode: Opcode { .sellRequest }

    /// The inventory slot index of the item to sell
    public let itemPosition: UInt8

    /// Extended (DWORD) avatar item code being sold
    public let avatar: UInt32

    public init(itemPosition: UInt8, avatar: UInt32) {
        self.itemPosition = itemPosition
        self.avatar = avatar
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        itemPosition = try UInt8(parsing: &input)
        avatar = try UInt32(parsingBigEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(itemPosition)
        output.write(avatar, endianness: .big)
    }
}
