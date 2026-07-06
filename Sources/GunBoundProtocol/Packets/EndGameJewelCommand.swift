/// End Game Jewel Command (`SVC_PLAY_END_JEWEL`)
///
/// Sent by the client to signal the end of a jewel-mode game.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct EndGameJewelCommand: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .endGameJewelCommand }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
