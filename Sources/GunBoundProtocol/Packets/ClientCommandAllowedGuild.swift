/// Client Command Allowed Guild (`SVC_CMD_SET_ALLOWEDGUILD`)
///
/// Sent by the server to push the list of guilds allowed on this server.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandAllowedGuild: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandAllowedGuild }

    public let guilds: [Guild]

    public init(guilds: [Guild]) {
        self.guilds = guilds
    }

    public init(parsing input: inout ParserSpan) throws {
        let count = try UInt8(parsing: &input)
        var guilds = [Guild]()
        guilds.reserveCapacity(Int(count))
        for _ in 0..<count {
            guilds.append(try Guild(parsing: &input))
        }
        self.guilds = guilds
    }

    public func encode(to output: inout ByteWriter) {
        output.write(array: guilds) { output, guild in
            guild.encode(to: &output)
        }
    }
}
