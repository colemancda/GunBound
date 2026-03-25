//
//  UserIdResponse.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// User ID Response
///
/// Response containing player information (encrypted)
public struct UserIdResponse: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .userResponse }

    /// The player's nickname (display name)
    public var nickname1: Username
    /// The player's secondary nickname (display name)
    public var nickname2: Username
    /// The player's guild name
    public var guild: Guild
    /// The player's rank for current season (points)
    public var rankCurrent: Int16
    /// The player's total games played
    public var rankSeason: Int16

    public init(
        nickname1: Username,
        nickname2: Username,
        guild: Guild = "",
        rankCurrent: Int16 = 0,
        rankSeason: Int16 = 0
    ) {
        self.nickname1 = nickname1
        self.nickname2 = nickname2
        self.guild = guild
        self.rankCurrent = rankCurrent
        self.rankSeason = rankSeason
    }
}
