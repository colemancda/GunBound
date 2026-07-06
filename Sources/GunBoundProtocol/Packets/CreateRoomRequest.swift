/// Create Room Request
///
/// Sent by the client to create a new game room.
/// The server validates the request and creates the room if possible.
///
/// **Usage:**
/// Used when a player clicks the "Create Room" button in the lobby.
/// The room is created with the specified name, settings, password, and capacity.
/// Upon success, the server sends a CreateRoomResponse and broadcasts the
/// new room to all players in the channel via RoomUpdateNotification.
///
/// **Settings Field:**
/// The settings field is a bitmask containing game configuration options
/// such as game mode, map, turn time, etc.
public struct CreateRoomRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .createRoomRequest }

    /// The name of the room to create
    public var name: String

    /// Game settings bitmask (game mode, map, turn time, etc.)
    public var settings: UInt32

    /// Optional room password (empty string for public rooms)
    public var password: RoomPassword

    /// Maximum number of players allowed in the room
    public var capacity: RoomCapacity

    public init(
        name: String,
        settings: UInt32,
        password: RoomPassword,
        capacity: RoomCapacity
    ) {
        self.name = name
        self.settings = settings
        self.password = password
        self.capacity = capacity
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.name = try String(parsingLengthPrefixedASCII: &input)
        self.settings = try UInt32(parsingLittleEndian: &input)
        self.password = try RoomPassword(parsing: &input)
        self.capacity = try RoomCapacity(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.writeLengthPrefixed(ascii: name)
        output.write(settings, endianness: .little)
        password.encode(to: &output)
        capacity.encode(to: &output)
    }
}
