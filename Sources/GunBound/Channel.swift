//
//  Channel.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// GunBound Channel
public struct Channel: Codable, Equatable, Hashable, Identifiable {
    
    public let id: ID
    
    public var users: Set<Username>
    
    public var message: String
}
