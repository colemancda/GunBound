import Foundation

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
public struct GiftRequest: GunBoundPacket, GunBoundDecodable, Decodable {

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

    public init(from container: GunBoundDecodingContainer) throws {
        recipient = try container.decode(Username.self)
        unknown = try container.decode(UInt32.self)
        itemPosition = try container.decode(UInt8.self)
        avatar = try container.decode(UInt32.self)
        let messageLength = try container.decode(UInt8.self)
        let messageBytes = try container.decode(Data.self, length: Int(messageLength))
        message = String(bytes: messageBytes, encoding: .utf8) ?? ""
    }
}
