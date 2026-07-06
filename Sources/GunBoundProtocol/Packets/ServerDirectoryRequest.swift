/// Server Directory Request
///
/// Sent by the client to request the list of available game servers.
/// Used during initial connection to discover available servers.
///
/// **Usage:**
/// Sent after establishing a connection to the broker server.
/// The server responds with a ServerDirectoryResponse containing
/// a list of available game servers that the client can connect to.
///
/// This allows the client to choose which server to play on.
public struct ServerDirectoryRequest: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .serverDirectoryRequest }

    /// Padding bytes (always 0x0000)
    let padding: UInt32

    public init() {
        self.padding = 0x0000
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.padding = try UInt32(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(padding, endianness: .little)
    }
}
