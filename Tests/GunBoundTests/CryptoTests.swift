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
    
    func testDecryptPassword() {
        
        let username = "testusername"
        let password = "testpassword"
        let nonce: Nonce = 0x00010203
        let key = Key(username: username, password: password, nonce: nonce)
        let encrypted = Data(hexString: "855F4B1102A6670C211C615FD886DFA72B0AB1164CC75A3DA8EBE5CBD3856EB75B47E9A28C2CA0A3A0ED467A12CBE942")!
        let decrypted = Data(hexString: "7465737470617373776F7264000000000000000018010000010AD3370320AB0000000000")!
        
        XCTAssertEqual(try Crypto.AES.decrypt(encrypted, key: key, opcode: .authenticationRequest), decrypted)
        XCTAssertEqual(String(data: decrypted.prefix(0xC), encoding: .ascii), password)
    }
    
    func testGenerateDynamicKey() {
        
        let username = "testusername"
        let password = "testpassword"
        let nonce: Nonce = 0x00010203
        
        let key = Key(username: username, password: password, nonce: nonce)
        XCTAssertEqual(key.description, "47E32B0B96C29B7E0B57880C2FA99A16")
        
        do {
            let rawKey = Key.plainText(username: username, password: password, nonce: nonce)
            XCTAssertEqual(rawKey.toHexadecimal(), "74657374757365726E616D657465737470617373776F7264000102038000000000000000000000000000000000000000000000000000000000000000000000E0")
        }
    }
    
    func testSHA0() {
        
        let plainText = Data(hexString: "74657374757365726E616D657465737470617373776F7264000102038000000000000000000000000000000000000000000000000000000000000000000000E0")!
        let output = Data(hexString: "47E32B0B96C29B7E0B57880C2FA99A16")!
        XCTAssertEqual(Crypto.SHA0.process(plainText), output)
        
        do {
            let data = [UInt8](plainText)
            var w = [UInt32]()
            Crypto.SHA0.sha0_process_block_0(data, w: &w)
            XCTAssertEqual(w, [1952805748, 1970496882, 1851878757, 1952805748, 1885434739, 2003792484, 66051, 2147483648, 0, 0, 0, 0, 0, 0, 0, 224])
            Crypto.SHA0.sha0_process_block_1(data, w: &w)
            XCTAssertEqual(w, [1952805748, 1970496882, 1851878757, 1952805748, 1885434739, 2003792484, 66051, 2147483648, 0, 0, 0, 0, 0, 0, 0, 224, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
            Crypto.SHA0.sha0_process_block_2(data, w: &w)
            XCTAssertEqual(w, [1952805748, 1970496882, 1851878757, 1952805748, 1885434739, 2003792484, 66051, 2147483648, 0, 0, 0, 0, 0, 0, 0, 224, 436477457, 18224646, 503324406, 420355841, 1903585142, 3916393618, 420420866, 4051068822, 4083905155, 404294404, 4017518944, 3932515714, 1768909938, 102307090, 3916328593, 2567904514, 4051068790, 3916393618, 420421090, 3950147943, 3900275348, 118424564, 3900209271, 2551778052, 3932450657, 4083905123, 118424564, 3983175318, 2601716244, 2669021200, 487202566, 1936355456, 2634751461, 3967580304, 2232620034, 2619083232, 2003726439, 2232620258, 2198471152, 1870035328, 4117980562, 1903650197, 1987667042, 454232820, 2147483872, 521537552, 404228583, 1885368688, 4068303973, 420420866, 4100223351, 4032918419, 1835756661, 18289669, 2650807830, 50987280, 1885368720, 3983240309, 18289893, 2214854887, 404228359, 1870035328, 4032918387, 1920820325])
        }
        
        do {
            let data = [UInt8](plainText)
            let sha_h = Crypto.SHA0.sha0_process_block(data)
            XCTAssertEqual(sha_h, [187425607, 2124137110, 210261771, 379234607, 2440093899])
        }
    }
}
