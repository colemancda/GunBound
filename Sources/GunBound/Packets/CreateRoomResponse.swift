//
//  CreateRoomResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Create Room response
public struct CreateRoomResponse: GunBoundPacket, Encodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .createRoomResponse }
    
    public var room: Room.ID
    
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
