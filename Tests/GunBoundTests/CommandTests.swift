//
//  CommandTests.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation
import XCTest
@testable import GunBound

final class CommandTests: XCTestCase {
    
    func testQuitCommand() throws {
        let arguments = ["q"]
        guard let _ = (try DefaultCommand.parseAsRoot(arguments)) as? QuitCommand else {
            XCTFail()
            return
        }
        
    }
    
    func testEchoCommand() throws {
        let arguments = ["echo", "hi"]
        guard let commandType = (try DefaultCommand.parseAsRoot(arguments)) as? EchoCommand else {
            XCTFail()
            return
        }
        XCTAssertEqual(commandType.message, "hi")
    }
    
    func testMobileCommand() throws {
        
        for mobile in Mobile.allCases {
            let arguments = ["mobile", mobile.rawValue.description]
            guard let commandType = (try DefaultCommand.parseAsRoot(arguments)) as? MobileCommand else {
                XCTFail()
                return
            }
            XCTAssertEqual(commandType.tank, mobile)
            print(arguments.reduce("", { $0 + ($0.isEmpty ? "" : " ") + $1 }), mobile)
        }
    }
}
