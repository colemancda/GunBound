//
//  Server.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation
import ArgumentParser
import GunBound

@main
struct Server: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "GunBoundServer",
        abstract: "GunBound Server emulator",
        version: "1.0.0",
        subcommands: [
            Broker.self,
            World.self
        ],
        defaultSubcommand: World.self
    )
}
