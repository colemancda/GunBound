//
//  CommandTests.swift
//
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import Testing
@testable import GunBound

@Suite struct CommandTests {

    @Test func quitCommand() throws {
        let arguments = ["q"]
        let command = try DefaultCommand.parseAsRoot(arguments)
        #expect(command is QuitCommand)
    }

    @Test func echoCommand() throws {
        let arguments = ["echo", "hi"]
        let command = try DefaultCommand.parseAsRoot(arguments)
        let echoCommand = try #require(command as? EchoCommand)
        #expect(echoCommand.message == "hi")
    }

    @Test func mobileCommand() throws {
        for mobile in Mobile.allCases {
            let arguments = ["mobile", mobile.rawValue.description]
            let command = try DefaultCommand.parseAsRoot(arguments)
            let mobileCommand = try #require(command as? MobileCommand)
            #expect(mobileCommand.tank == mobile)
        }
    }
}
