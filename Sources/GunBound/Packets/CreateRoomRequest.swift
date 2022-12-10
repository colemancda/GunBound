//
//  CreateRoomRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

public struct CreateRoomRequest: GunBoundPacket, Equatable, Hashable, Decodable {
    
    public static var opcode: Opcode { .createRoomRequest }
        
    public var name: String
    
    public var settings: UInt32
    
    public var password: RoomPassword
    
    public var capacity: UInt8
}

// MARK: - GunBoundDecodable

extension CreateRoomRequest: GunBoundDecodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.settings = try container.decode(UInt32.self, forKey: CodingKeys.settings)
        self.password = try container.decode(RoomPassword.self, forKey: CodingKeys.password)
        self.capacity = try container.decode(UInt8.self, forKey: CodingKeys.capacity)
    }
}
