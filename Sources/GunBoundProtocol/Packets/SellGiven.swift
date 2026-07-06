/// Sell Given (`SVC_PROP_SELL_GIVEN`)
///
/// Sent by the server to notify the client that an item was sold (mirrors
/// `SellRequest`'s fields).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct SellGiven: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .sellGiven }

    public let itemPosition: UInt8

    public let avatar: UInt32

    public init(itemPosition: UInt8, avatar: UInt32) {
        self.itemPosition = itemPosition
        self.avatar = avatar
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.itemPosition = try UInt8(parsing: &input)
        self.avatar = try UInt32(parsingBigEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(itemPosition)
        output.write(avatar, endianness: .big)
    }
}
