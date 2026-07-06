/// BCM (Broadcast Message)
///
/// Sent by the server to broadcast a message to all connected clients.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone;
/// this shape mirrors the sibling `ClientPrintNotification` (`0x5101`).
public struct Bcm: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .bcm }

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
