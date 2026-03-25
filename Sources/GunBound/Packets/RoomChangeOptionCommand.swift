//
//  RoomChangeOptionCommand.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Change Option Command
///
/// Sent by room host to change game options.
/// Only room host can send this command.
///
/// **Usage:**
/// Used to modify game settings like turn time, sudden death mode,
/// wind strength, and other gameplay options.
///
/// The settings field is a bitmask containing various game configuration options.
/// Upon successful change, server broadcasts RoomUpdateNotification to all players.
public struct RoomChangeOptionCommand: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .roomChangeOptionCommand }

    /// Game settings bitmask (turn time, sudden death, wind, etc.)
    public var settings: UInt32
}
