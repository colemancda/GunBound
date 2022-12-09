//
//  AuthenticationResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Authentication Response
public struct AuthenticationResponse: GunBoundPacket, Encodable, Hashable {
    
    public static var opcode: Opcode { .authenticationResponse }
    
    public let status: AuthenticationStatus
    
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
    
    struct UserData: Encodable, Hashable {
        
        public let session: UInt32
        
        public let username: String
        
        public let avatarEquipped: UInt64 // 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x00
        
        public let guild: String?
        
        public let rankCurrent: UInt16
        
        public let rankSeason: UInt16
        
        public let guildMemberCount: UInt16
        
        public let rankPositionCurrent: UInt16
        
        public let rankPositionSeason: UInt16
        
        public let guildRank: UInt16
        
        public let gpCurrent: UInt32
        
        public let gpSeason: UInt32
        
        public let gold: UInt32
        
        public let funcRestrict: FunctionRestrict
    }
}

extension AuthenticationResponse.UserData: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        //try container.encode(UInt16(0x0000)) // gender?
        try container.encode(session, isLittleEndian: false)//, forKey: CodingKeys.session) // session
        try container.encode(username, fixedLength: 0xC) // username
        try container.encode(avatarEquipped, forKey: CodingKeys.avatarEquipped) // default avatar
        try container.encode(guild ?? "", fixedLength: 8) // guild
        try container.encode(rankCurrent, forKey: CodingKeys.rankCurrent) // rank current
        try container.encode(rankSeason, forKey: CodingKeys.rankSeason) // rank season
        try container.encode(guildMemberCount, forKey: CodingKeys.guildMemberCount)
        try container.encode(rankPositionCurrent, forKey: CodingKeys.rankPositionCurrent)
        try container.encode(UInt16(0x0000))
        try container.encode(rankPositionSeason, forKey: CodingKeys.rankPositionSeason)
        try container.encode(UInt16(0x0000))
        try container.encode(guildRank, forKey: CodingKeys.guildRank)
        try container.encode(Data(repeating: 0x00, count: (4 * 4 * 20) + 10)) // shot history?
        try container.encode(gpCurrent, forKey: CodingKeys.gpCurrent)
        try container.encode(gpSeason, forKey: CodingKeys.gpSeason)
        try container.encode(gold, forKey: CodingKeys.gold)
        try container.encode(Data(repeating: 0x00, count: 17))
        try container.encode(funcRestrict, forKey: CodingKeys.funcRestrict)
    }
}
