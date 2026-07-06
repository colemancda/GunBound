/// Client Command Message of the Day (`SVC_CMD_MOTD`)
///
/// Sent by the server to push the message-of-the-day text to the client.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandMOTD: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandMOTD }

    public let message: String

    public init(message: String) {
        self.message = message
    }

    public init(parsing input: inout ParserSpan) throws {
        self.message = try String(parsingLengthPrefixedASCII: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.writeLengthPrefixed(ascii: message)
    }
}
