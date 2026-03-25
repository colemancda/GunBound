//
//  JoinChannelNotification.swift
//
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

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
public struct JoinChannelNotification: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .joinChannelNotification }

    /// The new player's user ID position in the channel
    public let channelPosition: Channel.UserID

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
        channelPosition: Channel.UserID,
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
}
