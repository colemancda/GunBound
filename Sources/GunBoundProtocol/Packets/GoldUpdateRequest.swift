/// Gold Update Request
///
/// Sent by the client to request the current gold balance.
/// The server responds with a GoldUpdateResponse containing the balance.
///
/// **Usage:**
/// Used when the client needs to refresh its cached gold balance,
/// typically after purchases, game rewards, or when opening the shop.
/// The server sends the player's current gold amount in the response.
public struct GoldUpdateRequest: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Hashable, Sendable {

    public static var opcode: Opcode { .goldUpdateRequest }

    public init() {}

    public init(parsing input: inout ParserSpan) throws(ParsingError) {}

    public func encode(to output: inout ByteWriter) { }
}
