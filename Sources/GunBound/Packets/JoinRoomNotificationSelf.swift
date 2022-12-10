//
//  JoinRoomNotificationSelf.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

public struct JoinRoomNotificationSelf: GunBoundPacket, Encodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .joinRoomNotificationSelf }
    
    internal let rtc: UInt16
    
    internal let value: UInt8
    
    public init() {
        self.rtc = 0x00
        self.value = 03
    }
}
