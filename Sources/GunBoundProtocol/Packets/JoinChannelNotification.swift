/// Join Channel Notification
///
/// Sent by the server to notify all clients in a channel that a player has joined.
/// Broadcast to all users in the channel when someone successfully joins.
///
/// **Usage:**
/// When a player joins a channel, this packet is broadcast to all other players
/// already in the channel. The client adds the new player to the user list display.
///
/// The player who joined also receives this packet (after JoinChannelResponse)
/// to confirm their presence in the channel.
public struct JoinChannelNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .joinChannelNotification }

    /// The new player's user ID position in the channel
    public let channelPosition: ChannelUserID

    /// The new player's username
    public let username: Username

    /// Bitmask of equipped avatar items (8 bytes)
    public let avatarEquipped: UInt64

    /// The player's guild information
    public let guild: Guild

    /// Current rank points
    public let rankCurrent: UInt16

    /// Season rank points
    public let rankSeason: UInt16

    public init(
        channelPosition: ChannelUserID,
        username: Username,
        avatarEquipped: UInt64,
        guild: Guild,
        rankCurrent: UInt16,
        rankSeason: UInt16
    ) {
        self.channelPosition = channelPosition
        self.username = username
        self.avatarEquipped = avatarEquipped
        self.guild = guild
        self.rankCurrent = rankCurrent
        self.rankSeason = rankSeason
    }

    public init(parsing input: inout ParserSpan) throws {
        self.channelPosition = try ChannelUserID(parsing: &input)
        self.username = try Username(parsing: &input)
        self.avatarEquipped = try UInt64(parsingLittleEndian: &input)
        self.guild = try Guild(parsing: &input)
        self.rankCurrent = try UInt16(parsingLittleEndian: &input)
        self.rankSeason = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        channelPosition.encode(to: &output)
        username.encode(to: &output)
        output.write(avatarEquipped, endianness: .little)
        guild.encode(to: &output)
        output.write(rankCurrent, endianness: .little)
        output.write(rankSeason, endianness: .little)
    }
}
