//
//  PlayerResurrectCommand.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Player Resurrect Command
///
/// Sent by the client when a player resurrects during gameplay.
/// Used to respawn a player who has been eliminated.
///
/// **Usage:**
/// Sent during active gameplay when a player uses a resurrection
/// ability or item to return to the game after being killed.
///
/// This packet is encrypted but contains no meaningful data.
/// The server validates the request and updates the game state
/// accordingly, notifying all players of the resurrection.
public struct PlayerResurrectCommand: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .playResurrect }

    public static var isEncrypted: Bool { true }

    /// Empty payload - packet is encrypted but has no meaningful data
    public init() {}
}
