//
//  JoinChannelRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// GunBound Join Channel Request packet
public struct JoinChannelRequest: GunBoundPacket, Equatable, Hashable, Codable {
    
    public static var opcode: Opcode { .joinChannelRequest }
        
    public let channel: Channel.ID
}
