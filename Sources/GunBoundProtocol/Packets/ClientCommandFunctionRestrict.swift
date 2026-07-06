/// Client Command Function Restrict (`SVC_CMD_FUNCTION_RESTRICT`)
///
/// Sent by the server to push the function-restriction bitmask (mirrors
/// `InMemoryGunBoundServerDataSource.State.functionRestrict`).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandFunctionRestrict: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandFunctionRestrict }

    public let functionRestrict: FunctionRestrict

    public init(functionRestrict: FunctionRestrict) {
        self.functionRestrict = functionRestrict
    }

    public func encode(to output: inout ByteWriter) {
        functionRestrict.encode(to: &output)
    }
}
