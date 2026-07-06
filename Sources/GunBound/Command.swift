//
//  Command.swift
//
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import ArgumentParser
import GunBoundProtocol

public protocol GunBoundCommand: AsyncParsableCommand {

    /// Run command
    mutating func execute(
        address: GunBoundAddress,
        username: Username?,
        dataSource: GunBoundServerDataSource
    ) async throws -> String?
}
