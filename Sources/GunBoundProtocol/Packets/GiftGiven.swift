/// Gift Given (`SVC_PROP_GIFT_GIVEN`)
///
/// Sent by the server to notify a player that they received a gifted item.
///
/// **Note:** This is a best-effort reconstruction mirroring `GiftRequest`'s fields.
public struct GiftGiven: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .giftGiven }

    public let sender: Username

    public let avatar: UInt32

    public init(sender: Username, avatar: UInt32) {
        self.sender = sender
        self.avatar = avatar
    }

    public init(parsing input: inout ParserSpan) throws {
        self.sender = try Username(parsing: &input)
        self.avatar = try UInt32(parsingBigEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        sender.encode(to: &output)
        output.write(avatar, endianness: .big)
    }
}
