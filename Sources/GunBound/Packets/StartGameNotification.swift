//
//  StartGameNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Start Game Notification
public struct StartGameNotification: GunBoundPacket, Encodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .startGameNotification }
    
    public let map: GameMap
    
    public let players: [Player]
    
    public let events: UInt16 // 0x00FF FuncRestrict?
    
    public let commandData: UInt32 // echo the stuff sent by game host
}

// MARK: - GunBoundCodable

extension StartGameNotification: GunBoundCodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        self.map = try container.decode(GameMap.self, forKey: CodingKeys.map)
        let playersCount = try container.decode(UInt16.self)
        self.players = try container.decode(Player.self, forKey: CodingKeys.players, count: Int(playersCount))
        self.events = try container.decode(UInt16.self, forKey: CodingKeys.events)
        self.commandData = try container.decode(UInt32.self, forKey: CodingKeys.commandData)
    }
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(map, forKey: CodingKeys.map)
        try container.encode(UInt16(players.count))
        try container.encodeArray(players, forKey: CodingKeys.players)
        try container.encode(events, forKey: CodingKeys.events)
        try container.encode(commandData, forKey: CodingKeys.commandData)
    }
}

// MARK: - Supporting Types

public extension StartGameNotification {
    
    struct Player: Codable, Equatable, Hashable, Identifiable {
        
        public let id: Room.PlayerSession.ID
        
        public let username: Username
        
        public let team: Team
        
        public let primaryTank: Mobile
        
        public let secondaryTank: Mobile
        
        public let xPosition: UInt16
        
        public let yPosition: UInt16
        
        public let turnOrder: UInt16
    }
}
