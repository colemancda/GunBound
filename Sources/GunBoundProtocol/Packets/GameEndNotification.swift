/// Game End Notification
///
/// Broadcast to every player in the room when the match is over. For
/// death-driven endings the payload is the winning team followed by
/// reserved zero bytes; for jewel mode the server relays the finishing
/// client's end-of-game payload unmodified, so the raw bytes are kept
/// accessible alongside the typed `winner` accessor.
public struct GameEndNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .gameEndNotification }

    /// Raw payload; the first byte is the winning team for death-driven
    /// endings.
    public let payload: [UInt8]

    /// The winning team, when the leading byte maps to one.
    public var winner: Team? {
        payload.first.flatMap { Team(rawValue: $0) }
    }

    public init(payload: [UInt8]) {
        self.payload = payload
    }

    /// Winner announcement: team byte + 11 reserved zero bytes (12 bytes
    /// total, one AES block).
    public init(winner: Team) {
        self.payload = [winner.rawValue] + [UInt8](repeating: 0, count: 11)
    }

    public init(parsing input: inout ParserSpan) throws {
        self.payload = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(payload)
    }
}
