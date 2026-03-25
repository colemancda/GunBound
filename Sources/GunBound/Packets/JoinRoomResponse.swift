//
//  JoinRoomResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

/// Join Room Response
///
/// Sent by the server in response to a JoinRoomRequest.
/// Confirms successful room join and provides complete room information.
///
/// **Usage:**
/// Sent to the client who requested to join the room.
/// Contains comprehensive room data including room name, map, settings,
/// capacity, and list of all players currently in the room.
///
/// After receiving this, the client should:
/// - Display the room interface with all player information
/// - Show the map and game settings
/// - Wait for additional JoinRoomNotification packets if more players join
/// - Expect RoomUpdateNotification for any room state changes
public struct JoinRoomResponse: GunBoundPacket, Encodable, Equatable, Hashable {

    public static var opcode: Opcode { .joinRoomResponse }

    /// Return code (0x0000 = success, non-zero = error)
    internal let rtc: UInt16

    /// Unknown value (typically 0x0100)
    internal let value0: UInt16

    /// The ID of the room that was joined
    public let room: Room.ID

    /// The name of the room
    public let name: String

    /// The game map selected for this room
    public let map: GameMap

    /// Game settings bitmask (game mode, turn time, etc.)
    public let settings: UInt32

    /// Unknown value (typically 0xFFFFFFFFFFFF)
    internal let value1: UInt64

    /// Maximum number of players allowed in the room
    public let capacity: RoomCapacity

    /// List of all players currently in the room
    public let players: [PlayerSession]

    /// Status or error message (empty on success)
    public let message: String
}

// MARK: - GunBoundEncodable

extension JoinRoomResponse: GunBoundEncodable {

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(rtc, forKey: CodingKeys.rtc)
        try container.encode(value0, forKey: CodingKeys.value0)
        try container.encode(room, forKey: CodingKeys.room)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(map, forKey: CodingKeys.map)
        try container.encode(settings, forKey: CodingKeys.settings)
        try container.encode(value1, forKey: CodingKeys.value1)
        try container.encode(capacity, forKey: CodingKeys.capacity)
        let playersCount = UInt8(players.count)
        try container.encode(playersCount)
        try container.encodeArray(players, forKey: CodingKeys.players)
        try container.encode(message.data(using: .ascii) ?? Data())
    }
}

// MARK: - Supporting Types

public extension JoinRoomResponse {

    /// Player information for a player in the room
    struct PlayerSession: Encodable, Equatable, Hashable, Identifiable {

        /// The player's position ID in the room (0-7)
        public let id: UInt8

        /// The player's username (12 bytes, null-padded)
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

        /// Unknown value
        internal let value0: UInt8

        /// Bitmask of equipped avatar items (8 bytes)
        public let avatarEquipped: UInt64

        /// The player's guild information
        public let guild: Guild

        /// Current rank points
        public let rankCurrent: UInt16

        /// Season rank points
        public let rankSeason: UInt16
    }
}
