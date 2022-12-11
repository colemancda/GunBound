//
//  UserReadyResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

/// User Ready response
public struct UserReadyResponse: GunBoundPacket, Equatable, Hashable, Codable {
    
    public static var opcode: Opcode { .roomUserReadyResponse }
    
    internal let rtc: UInt16
    
    public init() {
        self.rtc = 0x0000
    }
}
