//
//  User.swift
//
//
//  Created by Alsey Coleman Miller on 12/8/22.
//

import Foundation
import GunBoundProtocol

/// User
public struct User: Equatable, Hashable, Codable, Identifiable, Sendable {

    public let id: Username

    public var isBanned: Bool

    public var isAdmin: Bool {
        return rank == .administrator
    }

    public var rank: Rank

    public var gold: UInt32

    public var cash: UInt32

    public var avatarEquipped: UInt64

    public var guild: Guild

    public var rankCurrent: UInt16

    public var rankSeason: UInt16

    public var guildMemberCount: UInt16

    public var rankPositionCurrent: UInt16

    public var rankPositionSeason: UInt16

    public var guildRank: UInt16

    public var gpCurrent: UInt32

    public var gpSeason: UInt32

    public var avatarInventory: [UInt32]

    /// This account's buddy list — see `BuddyEntry`'s type-level note on
    /// why this is our own add/remove/list convention rather than a
    /// decomp-confirmed record shape.
    public var buddies: [Username]

    public init(
        id: Username,
        isBanned: Bool = false,
        rank: Rank = .chick,
        gold: UInt32 = 0,
        cash: UInt32 = 0,
        avatarEquipped: UInt64 = UInt64(0x0080_0080_0080_0000).bigEndian,
        guild: Guild = "",
        rankCurrent: UInt16 = 0,
        rankSeason: UInt16 = 0,
        guildMemberCount: UInt16 = 0,
        rankPositionCurrent: UInt16 = 0,
        rankPositionSeason: UInt16 = 0,
        guildRank: UInt16 = 0,
        gpCurrent: UInt32 = 0,
        gpSeason: UInt32 = 0,
        avatarInventory: [UInt32] = [],
        buddies: [Username] = []
    ) {
        self.id = id
        self.isBanned = isBanned
        self.rank = rank
        self.gold = gold
        self.cash = cash
        self.avatarEquipped = avatarEquipped
        self.guild = guild
        self.rankCurrent = rankCurrent
        self.rankSeason = rankSeason
        self.guildMemberCount = guildMemberCount
        self.rankPositionCurrent = rankPositionCurrent
        self.rankPositionSeason = rankPositionSeason
        self.guildRank = guildRank
        self.gpCurrent = gpCurrent
        self.gpSeason = gpSeason
        self.avatarInventory = avatarInventory
        self.buddies = buddies
    }
}
