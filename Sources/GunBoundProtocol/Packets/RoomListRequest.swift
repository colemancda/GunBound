/// Room List Request
///
/// Sent by the client to request a list of rooms in the current channel.
/// The server responds with a RoomListResponse containing room information.
///
/// **Usage:**
/// Sent when:
/// - First joining a channel
/// - Refreshing the room list
/// - Applying a filter to the room list
///
/// The filter parameter allows clients to request specific subsets of rooms
/// (e.g., only available rooms, specific game modes).
///
/// **Note:** Clients typically send this periodically to keep the room list
/// up to date with current player counts and room states.
public struct RoomListRequest: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomListRequest }

    /// Filter to apply to the room list
    public var filter: RoomFilter

    public init(filter: RoomFilter = .all) {
        self.filter = filter
    }

    public init(parsing input: inout ParserSpan) throws {
        self.filter = try RoomFilter(parsing: &input)
    }
}
