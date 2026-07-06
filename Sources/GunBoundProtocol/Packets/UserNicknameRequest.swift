/// User Nickname Request (`SVC_USER_NICK`)
///
/// Sent by the client to look up a user by nickname (mirrors `UserIdRequest`,
/// which looks up by username).
///
/// **Note:** This is a best-effort reconstruction mirroring `UserIdRequest`.
public struct UserNicknameRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userNicknameRequest }

    public let unknown: UInt16

    public let nickname: Username

    public init(unknown: UInt16, nickname: Username) {
        self.unknown = unknown
        self.nickname = nickname
    }

    public init(parsing input: inout ParserSpan) throws {
        self.unknown = try UInt16(parsingLittleEndian: &input)
        self.nickname = try Username(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(unknown, endianness: .little)
        nickname.encode(to: &output)
    }
}
