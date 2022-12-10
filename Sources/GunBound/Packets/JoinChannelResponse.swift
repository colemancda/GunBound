//
//  JoinChannelResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// GunBound Join Channel Request packet
public struct JoinChannelResponse: GunBoundPacket, Equatable, Hashable, Encodable {
    
    public static var opcode: Opcode { .joinChannelResponse }
    
    internal let status: UInt16
    
    public let channel: Channel
    
    public let maxPosition: UInt8
        
    public let users: [ChannelUser]
    
    public let channelMotd: String
}

// MARK: - GunBoundEncodable

extension JoinChannelResponse: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(status, forKey: CodingKeys.status)
        try container.encode(channel, forKey: CodingKeys.channel)
        try container.encode(maxPosition, forKey: CodingKeys.maxPosition)
        try container.encode(users, forKey: CodingKeys.users)
        try container.encode(channelMotd.data(using: .ascii) ?? Data())
    }
}

// MARK: - Supporting Types

public extension JoinChannelResponse {
    
    struct ChannelUser: Equatable, Hashable, Encodable {
                
        public let username: String
        
        public let avatarEquipped: UInt64
        
        public let guild: String?
        
        public let rankCurrent: UInt16
        
        public let rankSeason: UInt16
    }
}

extension JoinChannelResponse.ChannelUser: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(username, fixedLength: 12)
        try container.encode(avatarEquipped, forKey: CodingKeys.avatarEquipped)
        try container.encode(guild ?? "", fixedLength: 8)
        try container.encode(rankCurrent, forKey: CodingKeys.rankCurrent)
        try container.encode(rankSeason, forKey: CodingKeys.rankSeason)
    }
}
