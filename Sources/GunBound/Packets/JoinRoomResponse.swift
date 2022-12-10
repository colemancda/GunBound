//
//  JoinRoomResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

public struct JoinRoomResponse: GunBoundPacket, Encodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .joinRoomResponse }
    
    internal let rtc: UInt16
    
    internal let value0: UInt16 // 0x0100
    
    public let room: Room.ID
    
    public let name: String
    
    public let map: GameMap
    
    public let settings: UInt32
    
    internal let value1: UInt64 // 0xFFFFFFFFFFFF
    
    public let capacity: RoomCapacity
    
    public let players: [PlayerSession]
    
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
    
    struct PlayerSession: Encodable, Equatable, Hashable, Identifiable {
        
        public let id: UInt8
        
        public let username: Username // 0xC length
        
        public let ipAddress: UInt32 //IPv4Address
        
        public let port: UInt16 // 8363
        
        public let ipAddress2: UInt32 //IPv4Address
        
        public let port2: UInt16 // 8363
        
        public let primaryTank: Mobile
        
        public let secondary: Mobile
        
        public let team: Team
        
        internal let value0: UInt8
        
        public let avatarEquipped: UInt64
        
        public let guild: Guild
        
        public let rankCurrent: UInt16
        
        public let rankSeason: UInt16
    }
}
