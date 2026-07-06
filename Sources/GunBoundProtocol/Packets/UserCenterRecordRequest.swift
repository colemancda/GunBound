/// User Center Record Request
///
/// Sent by the client to request a user's record from the user center.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct UserCenterRecordRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userCenterRecordRequest }

    public let username: Username

    public init(username: Username) {
        self.username = username
    }

    public init(parsing input: inout ParserSpan) throws {
        self.username = try Username(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        username.encode(to: &output)
    }
}
