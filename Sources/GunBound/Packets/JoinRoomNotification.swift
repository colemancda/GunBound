//
//  JoinRoomNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

/// Join Room Notification
public struct JoinRoomNotification: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .joinRoomNotification }
    
    public let id: UInt8
    
    public let username: Username // 0xC length
    
    public let address: GunBoundAddress
        
    public let address2: GunBoundAddress
    
    public let primaryTank: Mobile
    
    public let secondary: Mobile
    
    public let team: Team
        
    public let avatarEquipped: UInt64
    
    public let guild: Guild
    
    public let rankCurrent: UInt16
    
    public let rankSeason: UInt16
}
