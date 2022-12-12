//
//  RoomReturnResultRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

/// Room Return Result Request
public struct RoomReturnResultResponse: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomReturnResultResponse }
    
    internal let rtc: UInt16
    
    public init() {
        self.rtc = 0x0000
    }
}
