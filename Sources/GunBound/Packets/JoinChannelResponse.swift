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
    
    public let channel: Channel.ID
    
    public let maxPosition: UInt8
    
    public let users: [ChannelUser]
    
    public let message: String
}

// MARK: - GunBoundEncodable

extension JoinChannelResponse: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(status, forKey: CodingKeys.status)
        try container.encode(channel, forKey: CodingKeys.channel)
        try container.encode(maxPosition, forKey: CodingKeys.maxPosition)
        try container.encode(users, forKey: CodingKeys.users)
        try container.encode(message.data(using: .ascii) ?? Data())
    }
}

// MARK: - Supporting Types

public extension JoinChannelResponse {
    
    struct ChannelUser: Equatable, Hashable, Encodable {
                
        public let username: Username
        
        public let avatarEquipped: UInt64
        
        public let guild: Guild
        
        public let rankCurrent: UInt16
        
        public let rankSeason: UInt16
    }
}
