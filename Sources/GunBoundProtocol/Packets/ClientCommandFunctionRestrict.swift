/// Client Command Function Restrict (`SVC_CMD_FUNCTION_RESTRICT`)
///
/// Sent by the server to push the function-restriction bitmask (mirrors
/// `InMemoryGunBoundServerDataSource.State.functionRestrict`).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandFunctionRestrict: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandFunctionRestrict }

    public let functionRestrict: FunctionRestrict

    public init(functionRestrict: FunctionRestrict) {
        self.functionRestrict = functionRestrict
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.functionRestrict = try FunctionRestrict(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        functionRestrict.encode(to: &output)
    }
}
