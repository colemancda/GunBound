//
//  RoomSelectTankRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Select Tank Request
///
/// Sent by the client to select mobile/tank types.
/// Players select their primary and secondary mobiles before the game starts.
///
/// **Usage:**
/// Used when a player wants to change their selected mobiles
/// in the room. Each player selects a primary mobile (the one
/// they will use in the game) and a secondary mobile (which may
/// be used for certain game modes or features).
///
/// Upon successful selection:
/// - Server validates the mobile selections
/// - Server broadcasts RoomUpdateNotification to all players
/// - Other players see the updated mobile selection in the room display
///
/// Note: Mobile selections cannot be changed once the game has started.
public struct RoomSelectTankRequest: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .roomSelectTankRequest }

    /// The primary mobile/tank selection
    public var primary: Mobile

    /// The secondary mobile/tank selection
    public var secondary: Mobile

    public init(
        primary: Mobile = .random,
        secondary: Mobile = .random
    ) {
        self.primary = primary
        self.secondary = secondary
    }
}
