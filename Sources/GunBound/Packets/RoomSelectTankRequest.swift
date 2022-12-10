//
//  RoomSelectTankRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Select Tank request
public struct RoomSelectTankRequest: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomSelectTankRequest }
    
    public var primary: Mobile
    
    public var secondary: Mobile
    
    public init(
        primary: Mobile = .random,
        secondary: Mobile = .random
    ) {
        self.primary = primary
        self.secondary = secondary
    }
}
