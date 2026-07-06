/// User Ready Request
///
/// Sent by the client to indicate ready status to the server.
/// The server updates the ready status and broadcasts to all players in the room.
public struct UserReadyRequest: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomUserReadyRequest }

    /// Whether the player is ready to start gameplay
    public var isReady: Bool

    public init(isReady: Bool) {
        self.isReady = isReady
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.isReady = try UInt8(parsing: &input) != 0
    }

    public func encode(to output: inout ByteWriter) {
        output.write(isReady)
    }
}
