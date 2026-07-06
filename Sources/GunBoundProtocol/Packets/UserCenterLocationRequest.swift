/// User Center Location Request (`RCTS_USER_LOCATION`)
///
/// Sent by the client to request a user's location from the user center.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct UserCenterLocationRequest: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userCenterLocationRequest }

    public let username: Username

    public init(parsing input: inout ParserSpan) throws {
        self.username = try Username(parsing: &input)
    }
}
