//
//  EchoCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import ArgumentParser

public struct EchoCommand: GunBoundCommand {
    
    public static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "echo")
    }
    
    @Argument
    public var message: String
    
    public init() { }
    
    public mutating func execute(
        address: GunBoundAddress,
        username: Username?,
        dataSource: GunBoundServerDataSource
    ) async throws -> String? {
        return message
    }
}
