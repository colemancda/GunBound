//
//  RoomReturnResultRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

/// Room Return Result Request
public struct RoomReturnResultRequest: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomReturnResultRequest }
    
    public init() { }
}
