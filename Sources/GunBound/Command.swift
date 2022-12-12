//
//  Command.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import ArgumentParser

public protocol GunBoundCommand: AsyncParsableCommand {
    
    /// Run command
    mutating func execute(
        address: GunBoundAddress,
        username: Username?,
        dataSource: GunBoundServerDataSource
    ) async throws -> String?
}
