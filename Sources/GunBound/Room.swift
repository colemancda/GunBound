//
//  Room.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

/// GunBound Room
public struct Room: Equatable, Hashable, Codable, Identifiable {
    
    public let id: ID
    
    public let channel: Channel.ID
    
    public var name: String
    
    public var password: RoomPassword
    
    public var map: GameMap
    
    public var settings: UInt32
    
    public var capacity: RoomCapacity
    
    public var isPlaying: Bool
    
    public var players: [PlayerSession]
    
    public var message: String
}

// MARK: - Supporting Types

public extension Room {
    
    /// Player Session
    struct PlayerSession: Equatable, Hashable, Codable, Identifiable {
        
        public let id: UInt8
        
        public let username: Username
                
        public let address: GunBoundAddress
        
        public var primaryTank: Mobile
        
        public var secondaryTank: Mobile
        
        public var team: Team
        
        public var isReady: Bool
        
        public var isAdmin: Bool
    }
}

// MARK: - Extensions

public extension Room {
    
    /// Whether a password is required to join the room.
    var isLocked: Bool {
        password.isEmpty == false
    }
    
    /// Find a free slot
    var nextID: Room.PlayerSession.ID? {
        let range = UInt8(0) ..< UInt8(0x10) // 16 max ID
        let usedIDs = players.lazy.map { $0.id } // don't allocate, just iterate
        return range.first {
            usedIDs.contains($0) == false
        }
    }
    
    /// Available team to insert new player.
    var nextTeam: Team {
        let playerTeams = players.lazy.map { $0.team }
        let aTeamCount = playerTeams.filter { $0 == .a }.count
        let bTeamCount = playerTeams.filter { $0 == .b }.count
        return aTeamCount > bTeamCount ? .b : .a
    }
}

public extension Sequence where Element == Room {
    
    /// Filter a sequence of rooms.
    func filter(
        _ filter: RoomFilter = .all,
        in channel: Channel.ID? = nil
    ) -> [Room] {
        return self.filter { room in
            if let channel = channel {
                guard room.channel == channel else {
                    return false
                }
            }
            if filter == .waiting {
                guard room.isPlaying == false else {
                    return false
                }
            }
            return true
        }
    }
    
    /// Find a free room ID.
    var nextID: Room.ID {
        let range = UInt16.min ..< UInt16.max
        let usedIDs = self.lazy.map { $0.id.rawValue } // don't allocate, just iterate
        let id = range
            .first { usedIDs.contains($0) == false }
            .map { Room.ID(rawValue: $0) }
        guard let id = id else {
            assertionFailure("No free room id")
            return .max
        }
        return id
    }
}
