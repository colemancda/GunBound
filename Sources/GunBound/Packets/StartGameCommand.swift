//
//  StartGameCommand.swift
//
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Start Game Command
///
/// Sent by the room host to start the game.
/// Only room host can send this command.
///
/// **Usage:**
/// Used when all players in the room are ready and the host
/// wants to begin the match. The server validates that all
/// players have selected their mobiles and are ready.
///
/// Upon successful start:
/// - Server sends StartGameNotification to all players
/// - Game transitions from lobby to playing state
/// - Players load the game map and begin gameplay
///
/// Note: Game cannot start if:
/// - Not all players are ready
/// - Not enough players (minimum 2)
/// - Game is already in progress
public struct StartGameCommand: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .startGameCommand }

    /// Internal value (purpose unknown)
    internal let value0: UInt32
}
