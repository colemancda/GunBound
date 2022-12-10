//
//  RoomSelectTeamRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Select Team request
public struct RoomSelectTeamRequest: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomSelectTeamRequest }
    
    public var team: Team
}
