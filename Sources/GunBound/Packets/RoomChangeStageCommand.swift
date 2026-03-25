//
//  RoomChangeStageCommand.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Change Map Command
///
/// Sent by room host to change the game map.
/// Only room host can send this command.
///
/// **Usage:**
/// Used when room host wants to select a different map
/// for the game.
///
/// Upon successful change:
/// - Server validates the map selection
/// - Server broadcasts RoomUpdateNotification to all players in room
/// - Room list in lobby is updated to reflect new map
///
/// Note: Map cannot be changed while a game is in progress.
public struct RoomChangeStageCommand: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .roomChangeStageCommand }

    /// The game map to change to
    public var map: GameMap
}
