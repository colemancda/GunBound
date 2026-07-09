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
public struct RoomListRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomListRequest }

    /// Rooms shown per page when a paginated request is made.
    public static let roomsPerPage = 6

    /// Filter to apply to the room list
    public var filter: RoomFilter

    /// Index of the first room of the requested page (0, 6, 12, …). When
    /// present the server returns at most ``roomsPerPage`` rooms starting
    /// there; when absent the full list is returned.
    public var startIndex: UInt8?

    public init(filter: RoomFilter = .all, startIndex: UInt8? = nil) {
        self.filter = filter
        self.startIndex = startIndex
    }

    public init(parsing input: inout ParserSpan) throws {
        self.filter = try RoomFilter(parsing: &input)
        self.startIndex = input.isEmpty ? nil : try UInt8(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        filter.encode(to: &output)
        if let startIndex {
            output.write(startIndex)
        }
    }
}
