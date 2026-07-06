/// Game Result Notification
///
/// Sent by the server in response to a GameResultCommand.
/// Triggers the display of the game results screen on the client.
///
/// **Usage:**
/// Broadcast to all players in the room when a game ends.
/// The client displays the results screen showing match statistics,
/// player scores, awards, and rewards.
///
/// This packet contains no data - it's a trigger signal only.
public struct GameResultNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .playResultNotification }

    public init() { }

    public init(parsing input: inout ParserSpan) throws(ParsingError) { }

    public func encode(to output: inout ByteWriter) { }
}
