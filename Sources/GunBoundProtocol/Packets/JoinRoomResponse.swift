/// Join Room Response
///
/// Sent by the server in response to a JoinRoomRequest.
/// Confirms successful room join and provides complete room information.
///
/// **Usage:**
/// Sent to the client who requested to join the room.
/// Contains comprehensive room data including room name, map, settings,
/// capacity, and list of all players currently in the room.
///
/// After receiving this, the client should:
/// - Display the room interface with all player information
/// - Show the map and game settings
/// - Wait for additional JoinRoomNotification packets if more players join
/// - Expect RoomUpdateNotification for any room state changes
public struct JoinRoomResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .joinRoomResponse }

    /// Return code (0x0000 = success, non-zero = error)
    internal let rtc: UInt16

    /// Whether the room join succeeded (a zero return code) — the client
    /// only enters the room (→ Ready Room, state 9) on success.
    public var isSuccess: Bool { rtc == 0x0000 }

    /// Unknown value (typically 0x0100)
    internal let value0: UInt16

    /// The ID of the room that was joined
    public let room: RoomID

    /// The name of the room
    public let name: String

    /// The game map selected for this room
    public let map: GameMap

    /// Game settings bitmask (game mode, turn time, etc.)
    public let settings: UInt32

    /// Unknown value (typically 0xFFFFFFFFFFFF)
    internal let value1: UInt64

    /// Maximum number of players allowed in the room
    public let capacity: RoomCapacity

    /// List of all players currently in the room
    public let players: [PlayerSession]

    /// Status or error message (empty on success)
    public let message: String

    public init(
        rtc: UInt16 = 0x0000,
        value0: UInt16 = 0x0100,
        room: RoomID,
        name: String,
        map: GameMap,
        settings: UInt32,
        value1: UInt64 = 0xFFFF_FFFF_FFFF,
        capacity: RoomCapacity,
        players: [PlayerSession],
        message: String = ""
    ) {
        self.rtc = rtc
        self.value0 = value0
        self.room = room
        self.name = name
        self.map = map
        self.settings = settings
        self.value1 = value1
        self.capacity = capacity
        self.players = players
        self.message = message
    }
}

// MARK: - Decoding

extension JoinRoomResponse {

    public init(parsing input: inout ParserSpan) throws {
        self.rtc = try UInt16(parsingLittleEndian: &input)
        self.value0 = try UInt16(parsingLittleEndian: &input)
        self.room = try RoomID(parsing: &input)
        self.name = try String(parsingLengthPrefixedASCII: &input)
        self.map = try GameMap(parsing: &input)
        self.settings = try UInt32(parsingLittleEndian: &input)
        self.value1 = try UInt64(parsingLittleEndian: &input)
        self.capacity = try RoomCapacity(parsing: &input)
        let count = try UInt8(parsing: &input)
        var players = [PlayerSession]()
        players.reserveCapacity(Int(count))
        for _ in 0..<count {
            players.append(try PlayerSession(parsing: &input))
        }
        self.players = players
        let messageBytes = [UInt8](parsingRemainingBytes: &input)
        self.message = String(decoding: messageBytes, as: UTF8.self)
    }
}

// MARK: - Encoding

extension JoinRoomResponse {

    public func encode(to output: inout ByteWriter) {
        output.write(rtc, endianness: .little)
        output.write(value0, endianness: .little)
        room.encode(to: &output)
        output.writeLengthPrefixed(ascii: name)
        map.encode(to: &output)
        output.write(settings, endianness: .little)
        output.write(value1, endianness: .little)
        capacity.encode(to: &output)
        output.write(UInt8(players.count))
        for player in players {
            player.encode(to: &output)
        }
        output.write(Array(message.utf8))
    }
}

// MARK: - Supporting Types

public extension JoinRoomResponse {

    /// Player information for a player in the room
    struct PlayerSession: Equatable, Hashable, Identifiable, Sendable {

        /// The player's position ID in the room (0-7)
        public let id: UInt8

        /// The player's username (12 bytes, null-padded)
        public let username: Username

        /// The player's network address (for P2P connections)
        public let address: GunBoundAddress

        /// Secondary network address (backup or internal address)
        public let address2: GunBoundAddress

        /// The player's primary mobile/tank selection
        public let primaryTank: Mobile

        /// The player's secondary mobile/tank selection
        public let secondary: Mobile

        /// The player's team assignment
        public let team: Team

        /// Unknown value
        internal let value0: UInt8

        /// Bitmask of equipped avatar items (8 bytes)
        public let avatarEquipped: UInt64

        /// The player's guild information
        public let guild: Guild

        /// Current rank points
        public let rankCurrent: UInt16

        /// Season rank points
        public let rankSeason: UInt16

        public init(
            id: UInt8,
            username: Username,
            address: GunBoundAddress,
            address2: GunBoundAddress,
            primaryTank: Mobile,
            secondary: Mobile,
            team: Team,
            value0: UInt8 = 0,
            avatarEquipped: UInt64,
            guild: Guild,
            rankCurrent: UInt16,
            rankSeason: UInt16
        ) {
            self.id = id
            self.username = username
            self.address = address
            self.address2 = address2
            self.primaryTank = primaryTank
            self.secondary = secondary
            self.team = team
            self.value0 = value0
            self.avatarEquipped = avatarEquipped
            self.guild = guild
            self.rankCurrent = rankCurrent
            self.rankSeason = rankSeason
        }
    }
}

extension JoinRoomResponse.PlayerSession {

    public init(parsing input: inout ParserSpan) throws {
        self.id = try UInt8(parsing: &input)
        self.username = try Username(parsing: &input)
        self.address = try GunBoundAddress(parsing: &input)
        self.address2 = try GunBoundAddress(parsing: &input)
        self.primaryTank = try Mobile(parsing: &input)
        self.secondary = try Mobile(parsing: &input)
        self.team = try Team(parsing: &input)
        self.value0 = try UInt8(parsing: &input)
        self.avatarEquipped = try UInt64(parsingLittleEndian: &input)
        self.guild = try Guild(parsing: &input)
        self.rankCurrent = try UInt16(parsingLittleEndian: &input)
        self.rankSeason = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(id)
        username.encode(to: &output)
        address.encode(to: &output)
        address2.encode(to: &output)
        primaryTank.encode(to: &output)
        secondary.encode(to: &output)
        team.encode(to: &output)
        output.write(value0)
        output.write(avatarEquipped, endianness: .little)
        guild.encode(to: &output)
        output.write(rankCurrent, endianness: .little)
        output.write(rankSeason, endianness: .little)
    }
}
