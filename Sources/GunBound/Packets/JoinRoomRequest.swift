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
