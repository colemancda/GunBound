/// Join Room Notification
///
/// Sent by the server to notify all clients in a room that a player has joined.
/// Broadcast to all users in the room when someone successfully joins.
///
/// **Usage:**
/// When a player joins a room, this packet is broadcast to all other players
/// already in the room. The client adds the new player to the room display.
///
/// The player who joined receives JoinRoomNotificationSelf instead, which contains
/// their complete player information.
public struct JoinRoomNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .joinRoomNotification }

    /// The new player's position ID in the room (0-7)
    public let id: UInt8

    /// The new player's username (12 bytes, null-padded)
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
        self.avatarEquipped = avatarEquipped
        self.guild = guild
        self.rankCurrent = rankCurrent
        self.rankSeason = rankSeason
    }

    public init(parsing input: inout ParserSpan) throws {
        self.id = try UInt8(parsing: &input)
        self.username = try Username(parsing: &input)
        self.address = try GunBoundAddress(parsing: &input)
        self.address2 = try GunBoundAddress(parsing: &input)
        self.primaryTank = try Mobile(parsing: &input)
        self.secondary = try Mobile(parsing: &input)
        self.team = try Team(parsing: &input)
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
        output.write(avatarEquipped, endianness: .little)
        guild.encode(to: &output)
        output.write(rankCurrent, endianness: .little)
        output.write(rankSeason, endianness: .little)
    }
}
