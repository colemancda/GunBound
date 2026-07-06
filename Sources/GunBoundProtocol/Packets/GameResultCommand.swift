/// Game Result Command
///
/// Sent by the client to request the game result screen.
/// This triggers the display of match statistics and awards.
///
/// **Usage:**
/// Sent at the end of a game to show the results to all players.
/// The server responds with a GameResultNotification containing
/// detailed match statistics, scores, and rewards.
///
/// This packet contains no data - it's a trigger signal only.
public struct GameResultCommand: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .playResultCommand }

    public init() { }

    public init(parsing input: inout ParserSpan) throws(ParsingError) { }

    public func encode(to output: inout ByteWriter) { }
}
