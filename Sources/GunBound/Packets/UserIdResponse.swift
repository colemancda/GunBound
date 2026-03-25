//
//  UserIdResponse.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// User ID Response
/// Response containing user information (encrypted)
public struct UserIdResponse: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .userResponse }

    public static var isEncrypted: Bool { true }

    public var nickname1: FixedLengthString<12>
    public var nickname2: FixedLengthString<12>
    public var guild: FixedLengthString<8>
    public var rankCurrent: Int16
    public var rankSeason: Int16

    public init(
        nickname1: FixedLengthString<12>,
        nickname2: FixedLengthString<12>,
        guild: FixedLengthString<8>,
        rankCurrent: Int16 = 0,
        rankSeason: Int16 = 0
    ) {
        self.nickname1 = nickname1
        self.nickname2 = nickname2
        self.guild = guild
        self.rankCurrent = rankCurrent
        self.rankSeason = rankSeason
    }

    public init(
        nickname: String,
        guild: String = "",
        rankCurrent: Int16 = 0,
        rankSeason: Int16 = 0
    ) {
        self.nickname1 = FixedLengthString(nickname)
        self.nickname2 = FixedLengthString(nickname)
        self.guild = FixedLengthString(guild)
        self.rankCurrent = rankCurrent
        self.rankSeason = rankSeason
    }
}
