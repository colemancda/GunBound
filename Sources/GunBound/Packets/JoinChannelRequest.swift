//
//  JoinChannelRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Join Channel Request
///
/// Sent by the client to join a specific game channel.
/// The server validates the request and moves the player to the channel.
///
/// **Usage:**
/// Used when a player selects a channel from the server directory
/// or after authentication to join a default channel.
///
/// Upon successful join:
/// - Server sends JoinChannelResponse to the joining player
/// - Server broadcasts JoinChannelNotification to all players in the channel
/// - Server sends RoomListResponse with current rooms in the channel
/// - Server sends JoinChannelNotification for each existing player in the channel
public struct JoinChannelRequest: GunBoundPacket, Equatable, Hashable, Codable {

    public static var opcode: Opcode { .joinChannelRequest }

    /// The ID of the channel to join
    public var channel: Channel.ID

    public init(channel: Channel.ID) {
        self.channel = channel
    }
}
