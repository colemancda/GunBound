/// Cash Update Request
///
/// Sent by the client to ask for a fresh cash balance — the original client
/// requests one when entering the shop, among other places. The server
/// answers with a ``CashUpdate`` notification (0x1032).
public struct CashUpdateRequest: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .cashUpdateRequest }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
