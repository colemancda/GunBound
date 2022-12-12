//
//  ClientPrintNotification.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation

public struct ClientPrintNotification: GunBoundPacket, Encodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .clientPrintNotification }
    
    public let message: String
}
