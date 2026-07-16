/// Buddy List Notification
///
/// Sent by the server after ``BuddyAddCommand``/``BuddyRemoveCommand`` — the
/// requester's refreshed buddy roster, the same shape as
/// ``BuddyListResponse`` but its own opcode since it isn't a reply to
/// ``BuddyListRequest``.
public struct BuddyListNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .buddyListNotification }

    public let buddies: [BuddyEntry]

    public init(buddies: [BuddyEntry]) {
        self.buddies = buddies
    }

    public init(parsing input: inout ParserSpan) throws {
        let count = try UInt8(parsing: &input)
        self.buddies = try Array(parsing: &input, count: Int(count), parser: BuddyEntry.init(parsing:))
    }

    public func encode(to output: inout ByteWriter) {
        output.write(array: buddies) { output, buddy in
            buddy.encode(to: &output)
        }
    }
}
