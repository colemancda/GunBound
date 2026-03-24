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

    public let events: UInt16  // 0x00FF FuncRestrict?

    public let commandData: UInt32  // echo the stuff sent by game host
}

// MARK: - GunBoundCodable

extension StartGameNotification: GunBoundCodable {

    public init(from container: GunBoundDecodingContainer) throws {
        self.map = try container.decode(GameMap.self, forKey: CodingKeys.map)
        let playersCount = try container.decode(UInt16.self, isLittleEndian: true)
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

// MARK: - GunBoundCodable

extension StartGameNotification.Player: GunBoundCodable {

    public init(from container: GunBoundDecodingContainer) throws {
        self.id = try container.decode(UInt8.self, forKey: CodingKeys.id)
        self.username = try container.decode(Username.self, forKey: CodingKeys.username)
        self.team = try container.decode(Team.self, forKey: CodingKeys.team)
        self.primaryTank = try container.decode(Mobile.self, forKey: CodingKeys.primaryTank)
        self.secondaryTank = try container.decode(Mobile.self, forKey: CodingKeys.secondaryTank)
        self.xPosition = try container.decode(UInt16.self, forKey: CodingKeys.xPosition)
        self.yPosition = try container.decode(UInt16.self, forKey: CodingKeys.yPosition)
        self.turnOrder = try container.decode(UInt16.self, forKey: CodingKeys.turnOrder)
    }

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(username, forKey: CodingKeys.username)
        try container.encode(team, forKey: CodingKeys.team)
        try container.encode(primaryTank, forKey: CodingKeys.primaryTank)
        try container.encode(secondaryTank, forKey: CodingKeys.secondaryTank)
        try container.encode(xPosition, forKey: CodingKeys.xPosition)
        try container.encode(yPosition, forKey: CodingKeys.yPosition)
        try container.encode(turnOrder, forKey: CodingKeys.turnOrder)
    }
}
