import Foundation

/// Gift Avatar Item Request (0x6030) — encrypted
public struct GiftRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .giftRequest }

    /// Recipient's username.
    public let recipient: Username

    /// Unknown DWORD field.
    public let unknown: UInt32

    /// Inventory slot index of the item to gift.
    public let itemPosition: UInt8

    /// Extended (DWORD) avatar item code.
    public let avatar: UInt32

    /// Optional gift message.
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
