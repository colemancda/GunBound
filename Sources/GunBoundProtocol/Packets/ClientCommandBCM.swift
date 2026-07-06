/// Client Command BCM (`SVC_CMD_BCM`)
///
/// Sent by the server to trigger a broadcast message.
///
/// **Note:** This is a best-effort reconstruction mirroring `Bcm` (`0x5010`).
public struct ClientCommandBCM: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandBCM }

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
