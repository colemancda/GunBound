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
