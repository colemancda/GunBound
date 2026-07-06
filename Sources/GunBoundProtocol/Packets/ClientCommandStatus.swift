/// Client Command Status (`SVC_CMD_STATUS`)
///
/// Sent by the server to update server status.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandStatus: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandStatus }

    public let status: UInt8

    public init(status: UInt8) {
        self.status = status
    }

    public func encode(to output: inout ByteWriter) {
        output.write(status)
    }
}
