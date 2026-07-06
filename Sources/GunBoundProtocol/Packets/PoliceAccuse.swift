/// Police Accuse (`SVC_POLICE_ACCUSE`)
///
/// Sent by the client to report another player (anti-cheat system).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct PoliceAccuse: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .policeAccuse }

    public let accused: Username

    public let reason: UInt8

    public init(parsing input: inout ParserSpan) throws {
        self.accused = try Username(parsing: &input)
        self.reason = try UInt8(parsing: &input)
    }
}
