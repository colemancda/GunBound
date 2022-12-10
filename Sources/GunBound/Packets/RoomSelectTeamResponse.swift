//
//  RoomSelectTeamResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Select Team Response
public struct RoomSelectTeamResponse: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomSelectTeamResponse }
    
    public let rtc: UInt16
    
    public init() {
        self.rtc = 0x00
    }
}
