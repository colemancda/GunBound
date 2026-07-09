/// End Game Jewel Command (`SVC_PLAY_END_JEWEL`)
///
/// Sent by the client to signal the end of a jewel-mode game. The payload
/// is the client's end-of-game summary; the server relays it unmodified to
/// every player in the room as a ``GameEndNotification`` (0x4410).
public struct EndGameJewelCommand: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .endGameJewelCommand }

    /// Opaque end-of-game summary, relayed to the room as-is.
    public let payload: [UInt8]

    public init(payload: [UInt8] = []) {
        self.payload = payload
    }

    public init(parsing input: inout ParserSpan) throws {
        self.payload = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(payload)
    }
}
