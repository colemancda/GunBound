//
//  CryptoTests.swift
//
//
//  Created by Alsey Coleman Miller on 12/7/22.
//

import Foundation
import Testing
@testable import GunBound

@Suite struct CryptoTests {

    @Test func decryptUsername() throws {
        let username = "testusername"
        let encrypted = Data([0x15, 0xE9, 0xA2, 0x89, 0x21, 0x09, 0x36, 0x86, 0x8C, 0xB9, 0xFA, 0xDA, 0x26, 0xCB, 0x0C, 0x0B])
        let decrypted = Data([0x74, 0x65, 0x73, 0x74, 0x75, 0x73, 0x65, 0x72, 0x6E, 0x61, 0x6D, 0x65, 0x00, 0x00, 0x00, 0x00])
        #expect(try Crypto.AES.decrypt(encrypted, key: .login) == decrypted)
        #expect(String(data: decrypted.prefix(while: { $0 != 0 }), encoding: .ascii) == username)
    }

    @Test func decryptPassword() throws {
        let username = "testusername"
        let password = "testpassword"
        let nonce: Nonce = 0x0001_0203
        let key = Key(username: username, password: password, nonce: nonce)
        let encrypted = Data(hexString: "855F4B1102A6670C211C615FD886DFA72B0AB1164CC75A3DA8EBE5CBD3856EB75B47E9A28C2CA0A3A0ED467A12CBE942")!
        let decrypted = Data(hexString: "7465737470617373776F7264000000000000000018010000010AD3370320AB0000000000")!
        #expect(try Crypto.AES.decrypt(encrypted, key: key, opcode: .authenticationRequest) == decrypted)
        #expect(String(data: decrypted.prefix(0xC), encoding: .ascii) == password)
    }

    @Test func encryptCash() throws {
        let plainText = Data(hexString: "3F420F00")!
        let encrypted = Data(hexString: "A791BE6CECA91C106A641B509550A630")!
        let key = Key(username: "admin", password: "1234", nonce: 0x0001_0203)
        #expect(try Crypto.AES.encrypt(plainText, key: key, opcode: .cashUpdateNotification) == encrypted)
    }

    @Test func generateDynamicKey() {
        let username = "testusername"
        let password = "testpassword"
        let nonce: Nonce = 0x0001_0203
        let key = Key(username: username, password: password, nonce: nonce)
        #expect(key.description == "47E32B0B96C29B7E0B57880C2FA99A16")
        let rawKey = Key.plainText(username: username, password: password, nonce: nonce)
        #expect(rawKey.toHexadecimal() == "74657374757365726E616D657465737470617373776F7264000102038000000000000000000000000000000000000000000000000000000000000000000000E0")
    }

    @Test func sha0() {
        let plainText = Data(hexString: "74657374757365726E616D657465737470617373776F7264000102038000000000000000000000000000000000000000000000000000000000000000000000E0")!
        let output = Data(hexString: "47E32B0B96C29B7E0B57880C2FA99A16")!
        #expect(Crypto.SHA0.process(plainText) == output)

        do {
            let data = [UInt8](plainText)
            var w = [UInt32]()
            Crypto.SHA0.sha0_process_block_0(data, w: &w)
            #expect(w == [1_952_805_748, 1_970_496_882, 1_851_878_757, 1_952_805_748, 1_885_434_739, 2_003_792_484, 66051, 2_147_483_648, 0, 0, 0, 0, 0, 0, 0, 224])
            Crypto.SHA0.sha0_process_block_1(data, w: &w)
            #expect(
                w == [
                    1_952_805_748, 1_970_496_882, 1_851_878_757, 1_952_805_748, 1_885_434_739, 2_003_792_484, 66051, 2_147_483_648, 0, 0, 0, 0, 0, 0, 0, 224, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                ])
            Crypto.SHA0.sha0_process_block_2(data, w: &w)
            #expect(
                w == [
                    1_952_805_748, 1_970_496_882, 1_851_878_757, 1_952_805_748, 1_885_434_739, 2_003_792_484, 66051, 2_147_483_648, 0, 0, 0, 0, 0, 0, 0, 224, 436_477_457, 18_224_646, 503_324_406,
                    420_355_841, 1_903_585_142, 3_916_393_618, 420_420_866, 4_051_068_822, 4_083_905_155, 404_294_404, 4_017_518_944, 3_932_515_714, 1_768_909_938, 102_307_090, 3_916_328_593,
                    2_567_904_514, 4_051_068_790, 3_916_393_618, 420_421_090, 3_950_147_943, 3_900_275_348, 118_424_564, 3_900_209_271, 2_551_778_052, 3_932_450_657, 4_083_905_123, 118_424_564,
                    3_983_175_318, 2_601_716_244, 2_669_021_200, 487_202_566, 1_936_355_456, 2_634_751_461, 3_967_580_304, 2_232_620_034, 2_619_083_232, 2_003_726_439, 2_232_620_258, 2_198_471_152,
                    1_870_035_328, 4_117_980_562, 1_903_650_197, 1_987_667_042, 454_232_820, 2_147_483_872, 521_537_552, 404_228_583, 1_885_368_688, 4_068_303_973, 420_420_866, 4_100_223_351,
                    4_032_918_419, 1_835_756_661, 18_289_669, 2_650_807_830, 50_987_280, 1_885_368_720, 3_983_240_309, 18_289_893, 2_214_854_887, 404_228_359, 1_870_035_328, 4_032_918_387,
                    1_920_820_325
                ])
        }

        do {
            let data = [UInt8](plainText)
            let sha_h = Crypto.SHA0.sha0_process_block(data)
            #expect(sha_h == [187_425_607, 2_124_137_110, 210_261_771, 379_234_607, 2_440_093_899])
        }
    }
}
