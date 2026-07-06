/// Room Return Result Request
///
/// Sent by the client to return game results after a match.
/// Used when the game is complete and players return to the lobby.
///
/// **Usage:**
/// Sent after a game ends when players want to return to the lobby.
/// This packet triggers the server to send RoomReturnResultResponse
/// with the final game results and statistics.
///
/// The server processes the request and updates player statistics,
/// awards gold/XP, and sends the result response to all players.
public struct RoomReturnResultRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomReturnResultRequest }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
