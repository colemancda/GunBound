//
//  User.swift
//  
//
//  Created by Alsey Coleman Miller on 12/8/22.
//

import Foundation

/// User
public struct User: Equatable, Hashable, Codable, Identifiable {
    
    public let id: String
    
    public var isBanned: Bool
    
    public var isAdmin: Bool {
        return rank == .administrator
    }
    
    public var rank: Rank
    
    public var gold: UInt
    
    public var cash: UInt
    
    public init(
        id: String,
        isBanned: Bool = false,
        rank: Rank = .chick,
        gold: UInt = 0,
        cash: UInt = 0
    ) {
        self.id = id
        self.isBanned = isBanned
        self.rank = rank
        self.gold = gold
        self.cash = cash
    }
}
