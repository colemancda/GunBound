//
//  JoinRoomNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

/// Join Room Notification
public struct JoinRoomNotification: GunBoundPacket, Encodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .joinRoomNotification }
    
    
}
