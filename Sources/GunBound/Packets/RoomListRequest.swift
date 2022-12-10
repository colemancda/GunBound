//
//  RoomListRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room List request
public struct RoomListRequest: GunBoundPacket, Equatable, Hashable, Codable {
    
    public static var opcode: Opcode { .roomListRequest }
    
    public var filter: RoomFilter
    
    public init(filter: RoomFilter = .all) {
        self.filter = filter
    }
}
