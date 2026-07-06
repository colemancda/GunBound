/// Rebroadcast
///
/// No payload; the original client treats this as a keepalive/ping
/// acknowledgment in the Ready Room, and as an unhandled fallthrough
/// In-Battle.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct Rebroadcast: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .rebroadcast }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
