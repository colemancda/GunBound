//
//  DefaultCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import ArgumentParser

public struct DefaultCommand: ParsableCommand {
    
    public static var configuration: CommandConfiguration {
        CommandConfiguration(subcommands: [
            QuitCommand.self,
            EchoCommand.self,
            MobileCommand.self
        ])
    }
    
    public init() { }
}
