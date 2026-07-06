/// Client Set Passable Authority (`SVC_CMD_SET_PASSABLE_AUTH`)
///
/// Sent by the server to set the passable authority level.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientSetPassableAuthority: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientSetPassableAuthority }

    public let level: UInt8

    public init(level: UInt8) {
        self.level = level
    }

    public func encode(to output: inout ByteWriter) {
        output.write(level)
    }
}
