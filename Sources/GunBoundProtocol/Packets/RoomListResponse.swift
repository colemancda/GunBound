/// Room List Response
///
/// Sent by the server in response to a RoomListRequest.
/// Contains a list of rooms in the current channel.
///
/// **Usage:**
/// The client displays these rooms in the lobby room list.
/// This packet is typically sent when:
/// - Player first joins a channel
/// - Player manually refreshes the room list
/// - Room list changes (rooms created/destroyed/updated)
///
/// The client should update its room list display with the
/// provided room information.
public struct RoomListResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomListResponse }

    /// List of rooms in the channel
    public var rooms: [Room]

    public init(rooms: [Room]) {
        self.rooms = rooms
    }
}

// MARK: - Decoding

extension RoomListResponse {

    public init(parsing input: inout ParserSpan) throws {
        _ = try UInt16(parsingLittleEndian: &input)  // RTC
        let count = try UInt16(parsingLittleEndian: &input)
        var rooms = [Room]()
        rooms.reserveCapacity(Int(count))
        for _ in 0..<count {
            rooms.append(try Room(parsing: &input))
        }
        self.rooms = rooms
    }
}

// MARK: - Encoding

extension RoomListResponse {

    public func encode(to output: inout ByteWriter) {
        output.write(UInt16(0x0000), endianness: .little)  // RTC
        output.write(UInt16(rooms.count), endianness: .little)
        for room in rooms {
            room.encode(to: &output)
        }
    }
}

// MARK: - ExpressibleByArrayLiteral

extension RoomListResponse: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Room...) {
        self.init(rooms: elements)
    }
}

// MARK: - Supporting Types

public extension RoomListResponse {

    /// Room information for display in the room list
    struct Room: Equatable, Hashable, Identifiable, Sendable {

        /// The room's unique ID
        public let id: RoomID

        /// The room's display name
        public let name: String

        /// The game map selected for this room
        public let map: GameMap

        /// Game settings bitmask (game mode, turn time, etc.)
        public let settings: UInt32

        /// Current number of players in the room
        public let playerCount: UInt8

        /// Maximum number of players allowed
        public let capacity: RoomCapacity

        /// Whether a game is currently in progress
        public let isPlaying: Bool

        /// Whether the room is password-protected
        public let isLocked: Bool

        public init(
            id: RoomID,
            name: String,
            map: GameMap,
            settings: UInt32,
            playerCount: UInt8,
            capacity: RoomCapacity,
            isPlaying: Bool,
            isLocked: Bool
        ) {
            self.id = id
            self.name = name
            self.map = map
            self.settings = settings
            self.playerCount = playerCount
            self.capacity = capacity
            self.isPlaying = isPlaying
            self.isLocked = isLocked
        }
    }
}

extension RoomListResponse.Room {

    public init(parsing input: inout ParserSpan) throws {
        self.id = try RoomID(parsing: &input)
        self.name = try String(parsingLengthPrefixedASCII: &input)
        self.map = try GameMap(parsing: &input)
        self.settings = try UInt32(parsingLittleEndian: &input)
        self.playerCount = try UInt8(parsing: &input)
        self.capacity = try RoomCapacity(parsing: &input)
        self.isPlaying = try UInt8(parsing: &input) != 0
        self.isLocked = try UInt8(parsing: &input) != 0
    }

    public func encode(to output: inout ByteWriter) {
        id.encode(to: &output)
        output.writeLengthPrefixed(ascii: name)
        map.encode(to: &output)
        output.write(settings, endianness: .little)
        output.write(playerCount)
        capacity.encode(to: &output)
        output.write(isPlaying)
        output.write(isLocked)
    }
}
