//
//  GameResultNotification.swift
//
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Game Result Notification
///
/// Sent by the server in response to a GameResultCommand.
/// Triggers the display of the game results screen on the client.
///
/// **Usage:**
/// Broadcast to all players in the room when a game ends.
/// The client displays the results screen showing match statistics,
/// player scores, awards, and rewards.
///
/// This packet contains no data - it's a trigger signal only.
public struct GameResultNotification: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .playResultNotification }
}
