/// Join Channel Response
///
/// Sent by the server in response to a JoinChannelRequest.
/// Confirms successful channel join and provides initial channel data.
///
/// **Usage:**
/// Sent to the client who requested to join the channel.
/// Contains the channel ID, maximum user position, list of users currently
/// in the channel (up to 255), and a status message.
///
/// After receiving this, the client should:
/// - Update the UI to show the new channel
/// - Display all users in the channel user list
/// - Wait for subsequent JoinChannelNotification packets for any additional users
/// - Expect a RoomListResponse with the current rooms in the channel
public struct JoinChannelResponse: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .joinChannelResponse }

    /// Status code (0x0000 = success, non-zero = error)
    internal let status: UInt16

    /// The ID of the channel that was joined
    public let channel: ChannelID

    /// The maximum user position index in the channel
    public let maxPosition: ChannelUserID

    /// List of users currently in the channel (max 255)
    public let users: [ChannelUser]

    /// Status or error message (empty on success)
    public let message: String

    public init(
        status: UInt16 = 0x0000,
        channel: ChannelID,
        maxPosition: ChannelUserID,
        users: [ChannelUser],
        message: String = ""
    ) {
        self.status = status
        self.channel = channel
        self.maxPosition = maxPosition
        self.users = users
        self.message = message
    }
}

// MARK: - Encoding

extension JoinChannelResponse {

    public func encode(to output: inout ByteWriter) {
        output.write(status, endianness: .little)
        channel.encode(to: &output)
        maxPosition.encode(to: &output)
        let maxUsers = Int(UInt8.max)
        output.write(UInt8(min(users.count, maxUsers)))  // write count
        for user in users.prefix(maxUsers) {
            user.encode(to: &output)
        }
        output.write(Array(message.utf8))
    }
}

// MARK: - Supporting Types

public extension JoinChannelResponse {

    /// User information for a player in the channel
    struct ChannelUser: Equatable, Hashable, Identifiable, Sendable {

        /// The user's position ID in the channel
        public let id: ChannelUserID

        /// The user's username
        public let username: Username

        /// Bitmask of equipped avatar items (8 bytes)
        public let avatarEquipped: UInt64

        /// The user's guild information
        public let guild: Guild

        /// Current rank points
        public let rankCurrent: UInt16

        /// Season rank points
        public let rankSeason: UInt16

        public init(
            id: ChannelUserID,
            username: Username,
            avatarEquipped: UInt64,
            guild: Guild,
            rankCurrent: UInt16,
            rankSeason: UInt16
        ) {
            self.id = id
            self.username = username
            self.avatarEquipped = avatarEquipped
            self.guild = guild
            self.rankCurrent = rankCurrent
            self.rankSeason = rankSeason
        }
    }
}

extension JoinChannelResponse.ChannelUser {

    public func encode(to output: inout ByteWriter) {
        id.encode(to: &output)
        username.encode(to: &output)
        output.write(avatarEquipped, endianness: .little)
        guild.encode(to: &output)
        output.write(rankCurrent, endianness: .little)
        output.write(rankSeason, endianness: .little)
    }
}
