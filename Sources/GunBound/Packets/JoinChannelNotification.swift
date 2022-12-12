//
//  JoinChannelNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

/// Join Channel Notification
public struct JoinChannelNotification: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .joinChannelNotification }
    
    public let channelPosition: Channel.UserID
    
    public let username: Username
    
    public let avatarEquipped: UInt64
    
    public let guild: Guild
    
    public let rankCurrent: UInt16
    
    public let rankSeason: UInt16
    
    public init(
        channelPosition: Channel.UserID,
        username: Username,
        avatarEquipped: UInt64,
        guild: Guild,
        rankCurrent: UInt16,
        rankSeason: UInt16
    ) {
        self.channelPosition = channelPosition
        self.username = username
        self.avatarEquipped = avatarEquipped
        self.guild = guild
        self.rankCurrent = rankCurrent
        self.rankSeason = rankSeason
    }
}
