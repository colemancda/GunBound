/// Buddy Add Command
///
/// Sent by the client (the buddy panel's Add button) to add a username to
/// its buddy list. Fire-and-forget: the server answers with a refreshed
/// ``BuddyListNotification``, not a direct response.
public struct BuddyAddCommand: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .buddyAddCommand }

    public let username: Username

    public init(username: Username) {
        self.username = username
    }

    public init(parsing input: inout ParserSpan) throws {
        self.username = try Username(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        username.encode(to: &output)
    }
}
