/// Buddy List Request
///
/// Sent by the client to fetch its current buddy roster (own convention —
/// see `BuddyEntry`'s type-level note on why this isn't the decomp's
/// unconfirmed buddy-locate opcode). The server answers with
/// ``BuddyListResponse``.
public struct BuddyListRequest: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .buddyListRequest }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
