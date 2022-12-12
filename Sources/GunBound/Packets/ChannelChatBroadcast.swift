//
//  ChannelChatBroadcast.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Channel Chat Broadcast
public struct ChannelChatBroadcast: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .channelChatBroadcast }
    
    public let position: Channel.UserID
    
    public let username: Username
    
    public let message: String
    
    public init(position: Channel.UserID,
         username: Username,
         message: String
    ) {
        self.position = position
        self.username = username
        self.message = message
    }
}
