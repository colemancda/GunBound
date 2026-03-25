//
//  JoinRoomRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Join Room Request
///
/// Sent by the client to join a specific game room.
/// The server validates the request and adds the player to the room.
///
/// **Usage:**
/// Used when a player double-clicks a room in the lobby room list
/// or selects a room and clicks "Join".
///
/// If the room is password-protected, the client must provide the correct password.
/// Empty password string indicates a public room.
///
/// Upon successful join:
/// - Server sends JoinRoomNotificationSelf to the joining player
/// - Server broadcasts JoinRoomNotification to all other players in the room
/// - Server sends JoinRoomNotification for each existing player in the room
public struct JoinRoomRequest: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .joinRoomRequest }

    /// The ID of the room to join
    public var room: Room.ID

    /// Room password (empty string for public rooms)
    public var password: RoomPassword

    public init(
        room: Room.ID,
        password: RoomPassword = ""
    ) {
        self.room = room
        self.password = password
    }
}
