//
//  GameResultCommand.swift
//
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Game Result Command
///
/// Sent by the client to request the game result screen.
/// This triggers the display of match statistics and awards.
///
/// **Usage:**
/// Sent at the end of a game to show the results to all players.
/// The server responds with a GameResultNotification containing
/// detailed match statistics, scores, and rewards.
///
/// This packet contains no data - it's a trigger signal only.
public struct GameResultCommand: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .playResultCommand }

}
