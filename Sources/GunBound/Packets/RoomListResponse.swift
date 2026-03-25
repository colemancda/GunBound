//
//  RoomListResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room List Response
///
/// Sent by the server in response to a RoomListRequest.
/// Contains a list of rooms in the current channel.
///
/// **Usage:**
/// The client displays these rooms in the lobby room list.
/// This packet is typically sent when:
/// - Player first joins a channel
/// - Player manually refreshes the room list
/// - Room list changes (rooms created/destroyed/updated)
///
/// The client should update its room list display with the
/// provided room information.
public struct RoomListResponse: GunBoundPacket, Equatable, Hashable, Encodable {

    public static var opcode: Opcode { .roomListResponse }

    /// List of rooms in the channel
    public var rooms: [Room]

    public init(rooms: [Room]) {
        self.rooms = rooms
    }
}

// MARK: - GunBoundEncodable

extension RoomListResponse: GunBoundEncodable {

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x0000))  // RTC
        try container.encode(UInt16(rooms.count))
        try container.encodeArray(rooms, forKey: CodingKeys.rooms)
    }
}

// MARK: - ExpressibleByArrayLiteral

extension RoomListResponse: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Room...) {
        self.init(rooms: elements)
    }
}

// MARK: - Supporting Types

public extension RoomListResponse {

    /// Room information for display in the room list
    struct Room: Equatable, Hashable, Encodable, Identifiable {

        /// The room's unique ID
        public let id: GunBound.Room.ID

        /// The room's display name
        public let name: String

        /// The game map selected for this room
        public let map: GameMap

        /// Game settings bitmask (game mode, turn time, etc.)
        public let settings: UInt32

        /// Current number of players in the room
        public let playerCount: UInt8

        /// Maximum number of players allowed
        public let capacity: RoomCapacity

        /// Whether a game is currently in progress
        public let isPlaying: Bool

        /// Whether the room is password-protected
        public let isLocked: Bool
    }
}
