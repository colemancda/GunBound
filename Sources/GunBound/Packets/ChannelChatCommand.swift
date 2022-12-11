//
//  ChannelChatCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// GunBound Channel Chat Command
public struct ChannelChatCommand: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .channelChatCommand }
    
    public var message: String
        
    public init(message: String) {
        self.message = message
    }
}
