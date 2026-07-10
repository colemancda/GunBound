//
//  Room.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import GunBoundProtocol

/// GunBound Room
public struct Room: Equatable, Hashable, Codable, Identifiable, Sendable {

    public typealias ID = RoomID

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

    /// Remaining lives per team while a score-mode game is in progress;
    /// `nil` outside of score-mode games.
    public var score: TeamScore? = nil
}

// MARK: - Supporting Types

public extension Room {

    /// Player Session
    struct PlayerSession: Equatable, Hashable, Codable, Identifiable, Sendable {

        public let id: UInt8

        public let username: Username

        public let address: GunBoundAddress

        public var primaryTank: Mobile

        public var secondaryTank: Mobile

        public var team: Team

        public var status: PlayerSlotStatus

        public var isAdmin: Bool
    }
}

public extension Room {

    /// Remaining lives per team in a score-mode game.
    struct TeamScore: Equatable, Hashable, Codable, Sendable {

        public var a: Int

        public var b: Int

        public init(a: Int, b: Int) {
            self.a = a
            self.b = b
        }
    }
}

// MARK: - PlayerSlotStatus

/// Per-slot status byte matching the server's room memory layout.
/// Corresponds to the byte at `room_base + slot * 8 + 7` in the original binary.
public enum PlayerSlotStatus: UInt8, Equatable, Hashable, Codable, Sendable {
    case waiting = 0x00  // in lobby, not ready
    case ready   = 0x03  // ready to start
    case alive   = 0x81  // in game, alive
    case dead    = 0x82  // in game, dead
}

// MARK: - Extensions

public extension Room {

    /// Whether a password is required to join the room.
    var isLocked: Bool {
        password.isEmpty == false
    }

    /// Find a free slot
    var nextID: Room.PlayerSession.ID? {
        let range = UInt8(0)..<UInt8(0x10)  // 16 max ID
        let usedIDs = players.lazy.map { $0.id }  // don't allocate, just iterate
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

    /// The room master (admin) session, if any.
    var master: PlayerSession? {
        players.first(where: { $0.isAdmin })
    }

    /// The game mode encoded in the settings bitmask.
    var gameMode: GunBoundProtocol.GameMode? {
        GunBoundProtocol.GameMode(settings: settings)
    }

    /// Elects the player in the lowest occupied slot as the new master.
    /// Returns the new master's slot, or `nil` if the room is empty.
    @discardableResult
    mutating func electNewMaster() -> PlayerSession.ID? {
        guard let index = players.indices.min(by: { players[$0].id < players[$1].id }) else {
            return nil
        }
        for i in players.indices {
            players[i].isAdmin = false
        }
        players[index].isAdmin = true
        return players[index].id
    }

    /// The winning team if the game has ended, `nil` while it is still in
    /// progress. In score mode the shared life pools are the *only* end
    /// condition — dead players respawn (the `0x4104` resurrect), so the
    /// momentary wipe between a death and its resurrect must not end the
    /// game. In every other mode a team with no alive players loses.
    var winningTeam: Team? {
        if gameMode == .score, let score = score {
            if score.a <= 0 { return .b }
            if score.b <= 0 { return .a }
            return nil
        }
        let teamAAlive = players.contains { $0.team == .a && $0.status == .alive }
        let teamBAlive = players.contains { $0.team == .b && $0.status == .alive }
        if teamAAlive == false { return .b }
        if teamBAlive == false { return .a }
        return nil
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
        let range = UInt16.min..<UInt16.max
        let usedIDs = self.lazy.map { $0.id.rawValue }  // don't allocate, just iterate
        let id =
            range
            .first { usedIDs.contains($0) == false }
            .map { Room.ID(rawValue: $0) }
        guard let id = id else {
            assertionFailure("No free room id")
            return .max
        }
        return id
    }
}
