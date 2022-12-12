//
//  MobileCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import ArgumentParser

public struct MobileCommand: GunBoundCommand {
    
    public static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "mobile")
    }
    
    @Argument
    public var tank: Mobile
    
    public init() { }
    
    public mutating func execute(
        address: GunBoundAddress,
        username: Username?,
        dataSource: GunBoundServerDataSource
    ) async throws -> String? {
        // find room for user
        guard let username = username else {
            throw GunBoundError.notAuthenticated
        }
        guard let roomID = try await dataSource.room(for: username) else {
            throw GunBoundError.notInRoom
        }
        // update tank in player session
        try await dataSource.update(room: roomID) { room in
            if let index = room.players.firstIndex(where: { $0.username == username }) {
                room.players[index].primaryTank = tank
            }
        }
        return "Set \(tank)"
    }
}

extension Mobile: ExpressibleByArgument {
    
    public init?(argument: String) {
        guard let rawValue = Mobile.RawValue(argument: argument),
            let value = Mobile(rawValue: rawValue) else {
            return nil
        }
        self = value
    }
}
