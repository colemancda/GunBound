/// Client Command Guild Mark Limit (`SVC_CMD_GUILDLIMIT`)
///
/// Sent by the server to push the guild-mark limit setting (mirrors the
/// `GuildMarkLimit` value parsed from `setting.txt`).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandGuildMarkLimit: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandGuildMarkLimit }

    public let limit: UInt16

    public init(limit: UInt16) {
        self.limit = limit
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.limit = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(limit, endianness: .little)
    }
}
