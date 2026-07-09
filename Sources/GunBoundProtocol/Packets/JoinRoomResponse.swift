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

    /// Return code for a join that was rejected: the room doesn't exist or
    /// the password is wrong.
    public static let errorBadRoom: UInt16 = 0x0011

    /// Return code for a join that was rejected because the room is full or
    /// the game is already in progress.
    public static let errorRoomFull: UInt16 = 0x2001

    /// Return code (0x0000 = success, non-zero = error)
    internal let rtc: UInt16

    /// Whether the room join succeeded (a zero return code) — the client
    /// only enters the room (→ Ready Room, state 9) on success.
    public var isSuccess: Bool { rtc == 0x0000 }

    /// Room slot of the current room master.
    public let masterSlot: UInt8

    /// Room slot assigned to the joining player.
    public let slot: UInt8

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
        masterSlot: UInt8 = 0,
        slot: UInt8 = 0,
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
        self.masterSlot = masterSlot
        self.slot = slot
        self.room = room
        self.name = name
        self.map = map
        self.settings = settings
        self.value1 = value1
        self.capacity = capacity
        self.players = players
        self.message = message
    }

    /// A rejected join: only the return code goes over the wire (the other
    /// fields mirror what decoding an error response produces).
    public static func error(_ rtc: UInt16) -> JoinRoomResponse {
        JoinRoomResponse(
            rtc: rtc,
            room: RoomID(rawValue: 0),
            name: "",
            map: .random,
            settings: 0,
            value1: 0,
            capacity: ._1_1,
            players: []
        )
    }
}

// MARK: - Decoding

extension JoinRoomResponse {

    public init(parsing input: inout ParserSpan) throws {
        self.rtc = try UInt16(parsingLittleEndian: &input)
        // A rejected join is just the return code — nothing else follows.
        guard rtc == 0x0000 else {
            self.masterSlot = 0
            self.slot = 0
            self.room = RoomID(rawValue: 0)
            self.name = ""
            self.map = .random
            self.settings = 0
            self.value1 = 0
            self.capacity = ._1_1
            self.players = []
            self.message = ""
            return
        }
        self.masterSlot = try UInt8(parsing: &input)
        self.slot = try UInt8(parsing: &input)
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
        // A rejected join is just the return code — nothing else follows.
        guard rtc == 0x0000 else { return }
        output.write(masterSlot)
        output.write(slot)
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
