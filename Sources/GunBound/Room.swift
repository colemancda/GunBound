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
    
    public var isLocked: Bool {
        password.isEmpty == false
    }
    
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

public extension Sequence where Element == Room {
    
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
}
