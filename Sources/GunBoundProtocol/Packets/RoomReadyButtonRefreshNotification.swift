/// Room Ready Button Refresh Notification
///
/// No payload. Tells the client to redraw its primary action button — a
/// "Ready" toggle for regular participants, or "Start Game" for the room
/// owner (only the owner can initiate the match-start countdown).
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomReadyButtonRefreshNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomReadyButtonRefreshNotification }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
