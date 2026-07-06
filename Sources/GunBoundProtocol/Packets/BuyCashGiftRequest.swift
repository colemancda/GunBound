/// Buy Cash Gift Request (`SVC_PROP_GIFT_BUY_PP`)
///
/// Sent by the client to purchase an avatar item with cash and gift it
/// directly to another player.
///
/// **Note:** This is a best-effort reconstruction mirroring `BuyCashRequest` and `GiftRequest`.
public struct BuyCashGiftRequest: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .buyCashGiftRequest }

    public let recipient: Username

    public let avatar: UInt32

    public init(parsing input: inout ParserSpan) throws {
        self.recipient = try Username(parsing: &input)
        self.avatar = try UInt32(parsingBigEndian: &input)
    }
}
