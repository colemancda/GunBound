//
//  RoomUpdateNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Update Notification
public struct RoomUpdateNotification: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomUpdateNotification }
    
    public let rtc: UInt16
    
    public init() {
        self.rtc = 0x00
    }
}
