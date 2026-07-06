/// Close Connection Notification
///
/// No payload. Tells the client the connection is being closed.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct CloseNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .close }

    public init() {}

    public init(parsing input: inout ParserSpan) throws {}

    public func encode(to output: inout ByteWriter) {}
}
