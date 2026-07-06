/// Buy Gold Gift Request (`SVC_PROP_GIFT_BUY`)
///
/// Sent by the client to purchase an avatar item with gold and gift it
/// directly to another player.
///
/// **Note:** This is a best-effort reconstruction mirroring `BuyGoldRequest` and `GiftRequest`.
public struct BuyGoldGiftRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .buyGoldGiftRequest }

    public let recipient: Username

    public let avatar: UInt32

    public init(recipient: Username, avatar: UInt32) {
        self.recipient = recipient
        self.avatar = avatar
    }

    public init(parsing input: inout ParserSpan) throws {
        self.recipient = try Username(parsing: &input)
        self.avatar = try UInt32(parsingBigEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        recipient.encode(to: &output)
        output.write(avatar, endianness: .big)
    }
}
