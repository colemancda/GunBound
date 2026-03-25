//
//  RoomSelectTeamRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Select Team Request
///
/// Sent by the client to select a team in the room.
/// Players can choose to join team A or team B.
///
/// **Usage:**
/// Used when a player wants to change their team assignment
/// in the room. Players can switch between Team A and Team B
/// before the game starts.
///
/// Upon successful team change:
/// - Server validates the team selection
/// - Server broadcasts RoomUpdateNotification to all players
/// - Other players see the player's team indicator change
///
/// Note: Team selection cannot be changed once the game has started.
/// Also, some game modes may have fixed team assignments.
public struct RoomSelectTeamRequest: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .roomSelectTeamRequest }

    /// The team to join (Team A or Team B)
    public var team: Team
}
