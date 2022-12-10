//
//  JoinRoomRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Join Room request
public struct JoinRoomRequest: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .joinRoomRequest }
    
    public var room: Room.ID
    
    public var password: RoomPassword
    
    public init(
        room: Room.ID,
        password: RoomPassword = ""
    ) {
        self.room = room
        self.password = password
    }
}

// MARK: - GunBoundCodable

extension JoinRoomRequest: GunBoundCodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        self.room = try container.decode(Room.ID.self, forKey: CodingKeys.room)
        self.password = try container.decode(RoomPassword.self, forKey: CodingKeys.password)
    }
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(room, forKey: CodingKeys.room)
        try container.encode(password, forKey: CodingKeys.password)
    }
}
