/// User Quit Notification
///
/// Observed with two meanings depending on screen, both no-payload: a simple
/// ready/unready toggle in the Ready Room, and a player-disconnected
/// mid-match signal while In-Battle (the disconnecting player's identity is
/// implicit from the connection itself, not carried in the payload).
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct UserQuitNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userQuitNotification }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
