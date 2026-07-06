/// Room Ready Confirmation Notification
///
/// No payload. A shared confirmation tail also reachable via the
/// team/tank/map-selection opcodes — may represent a generic "selection
/// confirmed" signal distinct from those more specific triggers, but
/// converging on the same underlying confirmation logic.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomReadyConfirmationNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomReadyConfirmationNotification }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
