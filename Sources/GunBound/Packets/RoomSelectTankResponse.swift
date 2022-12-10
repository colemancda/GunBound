//
//  RoomSelectTankResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Select Tank Response
public struct RoomSelectTankResponse: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomSelectTankResponse }
    
    public let rtc: UInt16
    
    public init() {
        self.rtc = 0x00
    }
}
