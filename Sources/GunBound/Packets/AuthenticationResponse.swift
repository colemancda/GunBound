//
//  AuthenticationResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Authentication Response
///
/// Sent by the server in response to an AuthenticationRequest.
/// Contains the authentication result and user data if successful.
///
/// **Possible Status Codes:**
/// - `.success` - Authentication successful, user data included
/// - `.badUsername` - Username not found
/// - `.badPassword` - Incorrect password
/// - `.bannedUser` - User account is banned
/// - `.badVersion` - Client version mismatch
///
/// **Usage:**
/// When authentication fails, only the status is sent.
/// When successful, the UserData structure contains all the player's
/// current account information including session ID, rank, gold, GP, etc.
public struct AuthenticationResponse: GunBoundPacket, Encodable, Hashable {

    public static var opcode: Opcode { .authenticationResponse }

    /// The authentication status/result
    public let status: AuthenticationStatus

    /// User account data (only included when status is `.success`)
    public let userData: UserData?

    private init(status: AuthenticationStatus, userData: UserData?) {
        self.status = status
        self.userData = userData
    }
}

public extension AuthenticationResponse {

    init(userData: UserData) {
        self.init(status: .success, userData: userData)
    }

    static var badUsername: AuthenticationResponse {
        AuthenticationResponse(status: .badUsername, userData: nil)
    }

    static var badPassword: AuthenticationResponse {
        AuthenticationResponse(status: .badPassword, userData: nil)
    }

    static var bannedUser: AuthenticationResponse {
        AuthenticationResponse(status: .bannedUser, userData: nil)
    }

    static var badVersion: AuthenticationResponse {
        AuthenticationResponse(status: .badVersion, userData: nil)
    }
}

// MARK: - Supporting Types

public extension AuthenticationResponse {

    /// User account data sent on successful authentication
    ///
    /// Contains all the player's current account information needed
    /// to initialize their game session.
    struct UserData: Encodable, Hashable {

        /// Unique session identifier for this connection (big-endian)
        public let session: UInt32

        /// The player's username
        public let username: Username

        /// Bitmask of equipped avatar items (8 bytes)
        /// Format: 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x00
        public let avatarEquipped: UInt64

        /// The player's guild information
        public let guild: Guild

        /// Current rank points
        public let rankCurrent: UInt16

        /// Season rank points
        public let rankSeason: UInt16

        /// Number of members in the player's guild
        public let guildMemberCount: UInt16

        /// Current season rank position (leaderboard standing)
        public let rankPositionCurrent: UInt16

        /// Season rank position (leaderboard standing)
        public let rankPositionSeason: UInt16

        /// Rank within the guild
        public let guildRank: UInt16

        /// Current GP (GunBound Points) - lifetime
        public let gpCurrent: UInt32

        /// Season GP points
        public let gpSeason: UInt32

        /// Current gold balance
        public let gold: UInt32

        /// Function restrictions (bitmask of disabled features)
        public let funcRestrict: FunctionRestrict
    }
}

extension AuthenticationResponse.UserData: GunBoundEncodable {

    public func encode(to container: GunBoundEncodingContainer) throws {
        //try container.encode(UInt16(0x0000)) // gender?
        try container.encode(session, isLittleEndian: false)  //, forKey: CodingKeys.session) // session
        try container.encode(username, forKey: CodingKeys.username)  // username
        try container.encode(avatarEquipped, forKey: CodingKeys.avatarEquipped)  // default avatar
        try container.encode(guild, forKey: CodingKeys.guild)  // guild
        try container.encode(rankCurrent, forKey: CodingKeys.rankCurrent)  // rank current
        try container.encode(rankSeason, forKey: CodingKeys.rankSeason)  // rank season
        try container.encode(guildMemberCount, forKey: CodingKeys.guildMemberCount)
        try container.encode(rankPositionCurrent, forKey: CodingKeys.rankPositionCurrent)
        try container.encode(UInt16(0x0000))
        try container.encode(rankPositionSeason, forKey: CodingKeys.rankPositionSeason)
        try container.encode(UInt16(0x0000))
        try container.encode(guildRank, forKey: CodingKeys.guildRank)
        try container.encode(Data(repeating: 0x00, count: (4 * 4 * 20) + 10))  // shot history?
        try container.encode(gpCurrent, forKey: CodingKeys.gpCurrent)
        try container.encode(gpSeason, forKey: CodingKeys.gpSeason)
        try container.encode(gold, forKey: CodingKeys.gold)
        try container.encode(Data(repeating: 0x00, count: 17))
        try container.encode(funcRestrict, forKey: CodingKeys.funcRestrict)
    }
}
