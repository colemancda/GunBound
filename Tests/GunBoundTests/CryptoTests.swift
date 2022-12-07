//
//  CryptoTests.swift
//  
//
//  Created by Alsey Coleman Miller on 12/7/22.
//

import Foundation
import XCTest
@testable import GunBound

final class CryptoTests: XCTestCase {
    
    func decryptUsername() throws {
        
        let username = "testusername"
        let encrypted = Data([0x15, 0xE9, 0xA2, 0x89, 0x21, 0x09, 0x36, 0x86, 0x8C, 0xB9, 0xFA, 0xDA, 0x26, 0xCB, 0x0C, 0x0B])
        let decrypted = Data([0x74, 0x65, 0x73, 0x74, 0x75, 0x73, 0x65, 0x72, 0x6E, 0x61, 0x6D, 0x65, 0x00, 0x00, 0x00, 0x00])
        
        XCTAssertEqual(try Crypto.AES.decrypt(encrypted, key: .login), decrypted)
        XCTAssertEqual(String(data: decrypted, encoding: .ascii), username)
    }
}
