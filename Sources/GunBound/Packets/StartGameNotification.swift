//
//  StartGameNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/11/22.
//

/// Start Game Notification
public struct StartGameNotification: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .startGameNotification }
    
    
}
