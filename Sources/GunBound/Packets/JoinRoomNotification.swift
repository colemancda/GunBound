//
//  JoinRoomNotification.swift
//
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

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
public struct JoinRoomNotification: GunBoundPacket, Codable, Equatable, Hashable {

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
}
