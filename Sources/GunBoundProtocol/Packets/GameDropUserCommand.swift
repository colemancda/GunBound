/// Game Drop User Command (`SVC_PLAY_DROP_USER`)
///
/// Sent by the server to drop/disconnect a user from the in-progress game.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct GameDropUserCommand: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .gameDropUserCommand }

    /// The room-slot ID of the player being dropped.
    public let playerID: UInt8

    public init(playerID: UInt8) {
        self.playerID = playerID
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.playerID = try UInt8(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(playerID)
    }
}
