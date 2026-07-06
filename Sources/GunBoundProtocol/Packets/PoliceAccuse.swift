/// Police Accuse (`SVC_POLICE_ACCUSE`)
///
/// Sent by the client to report another player (anti-cheat system).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct PoliceAccuse: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .policeAccuse }

    public let accused: Username

    public let reason: UInt8

    public init(accused: Username, reason: UInt8) {
        self.accused = accused
        self.reason = reason
    }

    public init(parsing input: inout ParserSpan) throws {
        self.accused = try Username(parsing: &input)
        self.reason = try UInt8(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        accused.encode(to: &output)
        output.write(reason)
    }
}
