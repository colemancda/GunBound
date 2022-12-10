//
//  CreateRoomRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

public struct CreateRoomRequest: GunBoundPacket, Equatable, Hashable, Decodable {
    
    public static var opcode: Opcode { .createRoomRequest }
        
    public var name: String
    
    public var settings: UInt32
    
    public var password: RoomPassword
    
    public var capacity: RoomCapacity
}
