/// Buddy List Response
///
/// Sent by the server in reply to ``BuddyListRequest`` — the requester's
/// full buddy roster with each entry's live online status.
public struct BuddyListResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .buddyListResponse }

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
