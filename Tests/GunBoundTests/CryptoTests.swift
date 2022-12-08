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
    
    func decryptPassword() {
        
        let username = "testusername"
        let password = "testpassword"
        let nonce: Nonce = 0x37C654B2
        let encrypted = Data(hexString: "EB9EADFF3DBC5704CA0A8510222E052D8438E4A7C3E3A7579542C3D9B3D41D3F5B431ED5DE835F3B40738A8CBF424C20")
        let decrypted = Data(hexString: "7465737470617373776F7264000000000000000018010000010AD3370320AB1F0080D80A")
        
        
    }
    
    func testGenerateDynamicKey() {
        
        let username = "testusername"
        let password = "testpassword"
        let nonce: Nonce = 0x37C654B2
    }
    
    func testSHA0() {
        
        let plainText = Data(hexString: "74657374757365726E616D657465737470617373776F72648452EFEE8000000000000000000000000000000000000000000000000000000000000000000000E0")!
        let output = Data(hexString: "19F4932EBE0CAE3ACB0D03F464FCAE06")!
        
        XCTAssertEqual(Crypto.SHA0.process(plainText).toHexadecimal(), output.toHexadecimal())
    }
}
