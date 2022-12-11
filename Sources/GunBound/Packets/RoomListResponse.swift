//
//  RoomListResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room List response
public struct RoomListResponse: GunBoundPacket, Equatable, Hashable, Encodable {
    
    public static var opcode: Opcode { .roomListResponse }
    
    public var rooms: [Room]
    
    public init(rooms: [Room]) {
        self.rooms = rooms
    }
}

// MARK: - GunBoundEncodable

extension RoomListResponse: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x0000)) // RTC
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
    
    struct Room: Equatable, Hashable, Encodable, Identifiable {
        
        public let id: GunBound.Room.ID
        
        public let name: String
        
        public let map: GameMap
        
        public let settings: UInt32
        
        public let playerCount: UInt8
        
        public let capacity: RoomCapacity
        
        public let isPlaying: Bool
        
        public let isLocked: Bool
    }
}
