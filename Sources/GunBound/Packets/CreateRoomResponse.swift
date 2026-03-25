//
//  CreateRoomResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Create Room Response
///
/// Sent by the server in response to a CreateRoomRequest.
/// Contains the ID of the newly created room and a status message.
///
/// **Usage:**
/// Sent to the client who requested the room creation.
/// The room ID is used to identify the room in all subsequent communications.
/// The message field typically contains status information or error messages.
///
/// Upon successful room creation, the server also broadcasts a RoomUpdateNotification
/// to all players in the channel to update the room list.
public struct CreateRoomResponse: GunBoundPacket, Encodable, Equatable, Hashable {

    public static var opcode: Opcode { .createRoomResponse }

    /// The ID of the newly created room
    public var room: Room.ID

    /// Status message (empty on success, contains error details on failure)
    public var message: String

    public init(
        room: Room.ID,
        message: String
    ) {
        self.room = room
        self.message = message
    }
}

extension CreateRoomResponse: GunBoundEncodable {

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(Data([0x00, 0x00, 0x00]))
        try container.encode(room, forKey: CodingKeys.room)
        try container.encode(message.data(using: .ascii) ?? Data())
    }
}
