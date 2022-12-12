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
    
    public var users: [UserID: Username]
    
    public var message: String
    
    public init(
        id: ID,
        users: [UserID : Username],
        message: String
    ) {
        self.id = id
        self.users = users
        self.message = message
    }
}

// MARK: - Methods

public extension Channel {
    
    subscript (id: UserID) -> Username? {
        get { users[id] }
        set { users[id] = newValue }
    }
    
    subscript (username: Username) -> UserID? {
        get { users.first(where: { $0.value == username })?.key }
    }
    
    var nextUserID: UserID? {
        let range = UInt8.min ..< .max
        return range
            .lazy
            .map { UserID(rawValue: $0) }
            .first { users.keys.contains($0) == false }
    }
    
    var maxUserID: UserID? {
        var maxID: UserID?
        for userID in users.keys {
            if userID.rawValue > (maxID?.rawValue ?? 0) {
                maxID = userID
            }
        }
        return maxID
    }
}
