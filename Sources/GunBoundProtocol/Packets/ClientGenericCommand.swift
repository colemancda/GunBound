/// Client Generic Command
///
/// Sent by the client to execute a generic command on the server.
/// This packet allows sending arbitrary command strings for processing.
///
/// **Usage:**
/// Used for various client-initiated commands that don't have dedicated packet types.
/// The command string is parsed by the server to determine the action to take.
///
/// **Note:** The value0 field's purpose is currently unknown and may be unused.
public struct ClientGenericCommand: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommand }

    /// Unknown field (purpose not yet determined)
    internal let value0: UInt8

    /// The command string to execute
    public let command: String

    internal init(value0: UInt8, command: String) {
        self.value0 = value0
        self.command = command
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.value0 = try UInt8(parsing: &input)
        let commandBytes = [UInt8](parsingRemainingBytes: &input)
        self.command = String(decoding: commandBytes, as: UTF8.self)
    }
}
