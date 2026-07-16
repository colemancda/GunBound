/// Buddy Remove Command
///
/// Sent by the client (the buddy panel's Del button) to remove a username
/// from its buddy list. Fire-and-forget: the server answers with a
/// refreshed ``BuddyListNotification``, not a direct response.
public struct BuddyRemoveCommand: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .buddyRemoveCommand }

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
