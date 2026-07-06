/// Room Change Team Notification (tentative)
///
/// Inferred from the surrounding opcode cluster's apparent theme
/// (character/team/map/ready selection) rather than proven via an explicit
/// string reference.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomChangeTeamNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomChangeTeamNotification }

    /// Reserved/unused (purpose not confirmed by static analysis).
    public let reserved0: UInt16

    /// Reserved/unused (purpose not confirmed by static analysis).
    public let reserved1: UInt16

    public let team: Team

    public init(reserved0: UInt16 = 0, reserved1: UInt16 = 0, team: Team) {
        self.reserved0 = reserved0
        self.reserved1 = reserved1
        self.team = team
    }

    public init(parsing input: inout ParserSpan) throws {
        self.reserved0 = try UInt16(parsingLittleEndian: &input)
        self.reserved1 = try UInt16(parsingLittleEndian: &input)
        self.team = try Team(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(reserved0, endianness: .little)
        output.write(reserved1, endianness: .little)
        team.encode(to: &output)
    }
}
