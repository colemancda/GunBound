//
//  JoinChannelResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

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
public struct JoinChannelResponse: GunBoundPacket, Equatable, Hashable, Encodable {

    public static var opcode: Opcode { .joinChannelResponse }

    /// Status code (0x0000 = success, non-zero = error)
    internal let status: UInt16

    /// The ID of the channel that was joined
    public let channel: Channel.ID

    /// The maximum user position index in the channel
    public let maxPosition: Channel.UserID

    /// List of users currently in the channel (max 255)
    public let users: [ChannelUser]

    /// Status or error message (empty on success)
    public let message: String
}

// MARK: - GunBoundEncodable

extension JoinChannelResponse: GunBoundEncodable {

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(status, forKey: CodingKeys.status)
        try container.encode(channel, forKey: CodingKeys.channel)
        try container.encode(maxPosition, forKey: CodingKeys.maxPosition)
        let maxUsers = Int(UInt8.max)
        try container.encode(UInt8(min(users.count, maxUsers)))  // write count
        try container.encodeArray(users.prefix(maxUsers), forKey: CodingKeys.users)
        try container.encode(message.data(using: .ascii) ?? Data())
    }
}

// MARK: - Supporting Types

public extension JoinChannelResponse {

    /// User information for a player in the channel
    struct ChannelUser: Equatable, Hashable, Encodable, Identifiable {

        /// The user's position ID in the channel
        public let id: Channel.UserID

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
    }
}
