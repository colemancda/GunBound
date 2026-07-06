/// User Info (`SVC_USER_INFO`)
///
/// Sent by the server to broadcast a user's information.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct UserInfo: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userInfo }

    public let username: Username

    public let status: UInt8

    public init(username: Username, status: UInt8) {
        self.username = username
        self.status = status
    }

    public init(parsing input: inout ParserSpan) throws {
        self.username = try Username(parsing: &input)
        self.status = try UInt8(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        username.encode(to: &output)
        output.write(status)
    }
}
