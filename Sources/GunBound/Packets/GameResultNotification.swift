//
//  GameResultNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Game Result Notification
public struct GameResultNotification: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .playResultNotification }
}
