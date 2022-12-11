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
    
    public let ipAddress: UInt32 //IPv4Address
    
    public let port: UInt16 // 8363
    
    public let ipAddress2: UInt32 //IPv4Address
    
    public let port2: UInt16 // 8363
    
    public let primaryTank: Mobile
    
    public let secondary: Mobile
    
    public let team: Team
        
    public let avatarEquipped: UInt64
    
    public let guild: Guild
    
    public let rankCurrent: UInt16
    
    public let rankSeason: UInt16
}
