//
//  QuitCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import ArgumentParser

public struct QuitCommand: GunBoundCommand {
    
    public static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "q")
    }
    
    public init() { }
    
    public mutating func execute(
        address: GunBoundAddress,
        username: Username?,
        dataSource: GunBoundServerDataSource
    ) async throws -> String? {
        return "Will close connection for \(address.address)..."
    }
}
