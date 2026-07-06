/// Gift Avatar Item Request
///
/// Sent by the client to gift an avatar item to another player.
/// The item is transferred from the sender's inventory to the recipient.
///
/// **Opcode:** 0x6030
///
/// **Usage:**
/// Used when a player wants to send an avatar item from their inventory
/// to another player as a gift. The server validates the request, deducts
/// the item from the sender's inventory, and adds it to the recipient's inventory.
///
/// The recipient will receive a notification about the gift. If the recipient
/// is offline, the gift is typically held in their inventory until they log in.
///
/// **Note:** This packet is encrypted and requires decryption before processing.
public struct GiftRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Sendable {

    public static var opcode: Opcode { .giftRequest }

    /// The username of the player receiving the gift
    public let recipient: Username

    /// Unknown field (purpose not yet determined)
    public let unknown: UInt32

    /// The inventory slot index of the item being gifted
    public let itemPosition: UInt8

    /// Extended (DWORD) avatar item code being gifted
    public let avatar: UInt32

    /// Optional message to include with the gift
    public let message: String

    public init(recipient: Username, unknown: UInt32, itemPosition: UInt8, avatar: UInt32, message: String) {
        self.recipient = recipient
        self.unknown = unknown
        self.itemPosition = itemPosition
        self.avatar = avatar
        self.message = message
    }

    public init(parsing input: inout ParserSpan) throws {
        recipient = try Username(parsing: &input)
        unknown = try UInt32(parsingBigEndian: &input)
        itemPosition = try UInt8(parsing: &input)
        avatar = try UInt32(parsingBigEndian: &input)
        let messageLength = try Int(UInt8(parsing: &input))
        let messageBytes = try [UInt8](parsing: &input, byteCount: messageLength)
        message = String(decoding: messageBytes, as: UTF8.self)
    }

    public func encode(to output: inout ByteWriter) {
        recipient.encode(to: &output)
        output.write(unknown, endianness: .big)
        output.write(itemPosition)
        output.write(avatar, endianness: .big)
        output.writeLengthPrefixed(ascii: message)
    }
}
