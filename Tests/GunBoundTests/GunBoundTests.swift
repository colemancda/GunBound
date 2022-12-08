import XCTest
@testable import GunBound

final class GunBoundTests: XCTestCase {
    
    func testAddress() {
        XCTAssertEqual(GunBoundAddress(rawValue: "192.168.1.1:1234")?.address, "192.168.1.1")
        XCTAssertEqual(GunBoundAddress(rawValue: "192.168.1.1:1234")?.port, 1234)
        XCTAssertEqual(GunBoundAddress(rawValue: "192.168.1.1:1234")?.rawValue, "192.168.1.1:1234")
        XCTAssertNil(GunBoundAddress(rawValue: "192.168.1.1"))
    }
    
    func testServerDirectoryRequest() {
        
        /*
         0a 00 a5 46 00 11 00 00 00 00
         Server Directory Request
         */
        
        let data = Data([
            0x0a, 0x00,
            0xa5, 0x46,
            0x00, 0x11,
            0x00, 0x00, 0x00, 0x00
        ])
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 10)
        XCTAssertEqual(packet.data.count, 10)
        XCTAssertEqual(packet.opcode, .serverDirectoryRequest)
        XCTAssertEqual(packet.id, 0x46A5)
        XCTAssertEqual(packet.parametersSize, 4)
        XCTAssertEqual(packet.parameters, Data([0x00, 0x00, 0x00, 0x00]))
        XCTAssertEncode(ServerDirectoryRequest(), id: 0x46A5, data)
        
    }
    
    func testServerDirectoryResponse() throws {
        
        do {
            let data = Data([0x48, 0x00, 0x2b, 0xcb, 0x02, 0x11, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x0e, 0x4a, 0x47, 0x20, 0x54, 0x65, 0x73, 0x74, 0x20, 0x42, 0x72, 0x6f, 0x6b, 0x65, 0x72, 0x1e, 0x42, 0x72, 0x6f, 0x6b, 0x65, 0x72, 0x20, 0x64, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x69, 0x6f, 0x6e, 0x5c, 0x6e, 0x20, 0x67, 0x6f, 0x65, 0x73, 0x20, 0x68, 0x65, 0x72, 0x65, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01])
            
            let jsonString = #"""
                [{
                    "name": "JG Test Broker",
                    "description": "Broker description\\n goes here",
                    "address": "192.168.1.1",
                    "port": 8370,
                    "utilization": 0,
                    "capacity": 100,
                    "enabled": true
                }]
            """#
            
            let jsonDecoder = JSONDecoder()
            let serverDirectory = try jsonDecoder.decode(ServerDirectory.self, from: Data(jsonString.utf8))
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 72)
            XCTAssertEqual(packet.data.count, 72)
            XCTAssertEqual(packet.id, .init(serverPacketLength: packet.data.count))
            XCTAssertEqual(packet.id, 0xCB2B)
            XCTAssertEqual(packet.opcode, .serverDirectoryResponse)
            XCTAssertEqual(packet.parametersSize, packet.data.count - 6)
            
            XCTAssertEqual(serverDirectory.count, 1)
            XCTAssertEqual(serverDirectory[0].name, "JG Test Broker")
            XCTAssertEqual(serverDirectory[0].descriptionText, #"Broker description\n goes here"#)
            XCTAssertEncode(ServerDirectoryResponse(directory: serverDirectory), data)
        }
        
        do {
            /*
             Server Directory Response
             
             0000   18 01 bb 08 02 11 00 00 01 05 00 00 00 0e 4a 47   ..............JG
             0010   20 54 65 73 74 20 42 72 6f 6b 65 72 1e 42 72 6f    Test Broker.Bro
             0020   6b 65 72 20 64 65 73 63 72 69 70 74 69 6f 6e 5c   ker description\
             0030   6e 20 67 6f 65 73 20 68 65 72 65 c0 a8 01 01 20   n goes here....
             0040   b2 00 00 00 00 00 64 01 01 00 00 09 46 72 65 65   ......d.....Free
             0050   20 50 6c 61 79 16 52 6f 6f 6b 69 65 20 5a 6f 6e    Play.Rookie Zon
             0060   65 5c 6e 41 76 61 74 61 72 20 4f 4e c0 a8 01 01   e\nAvatar ON....
             0070   20 a9 00 32 00 32 00 64 01 02 00 00 0f 44 69 73    ..2.2.d.....Dis
             0080   61 62 6c 65 64 20 53 65 72 76 65 72 16 52 6f 6f   abled Server.Roo
             0090   6b 69 65 20 5a 6f 6e 65 5c 6e 41 76 61 74 61 72   kie Zone\nAvatar
             00a0   20 4f 4e c0 a8 01 01 20 aa 00 32 00 32 00 64 00    ON.... ..2.2.d.
             00b0   03 00 00 0b 46 75 6c 6c 20 53 65 72 76 65 72 16   ....Full Server.
             00c0   52 6f 6f 6b 69 65 20 5a 6f 6e 65 5c 6e 41 76 61   Rookie Zone\nAva
             00d0   74 61 72 20 4f 4e c0 a8 01 01 20 ab 00 64 00 64   tar ON.... ..d.d
             00e0   00 64 01 04 00 00 0f 4c 6f 6f 70 62 61 63 6b 20   .d.....Loopback
             00f0   53 65 72 76 65 72 14 6c 6f 63 61 6c 68 6f 73 74   Server.localhost
             0100   5c 6e 50 6f 72 74 20 38 33 37 30 7f 00 00 01 20   \nPort 8370....
             0110   b2 00 00 00 00 00 64 01                           ......d.
             */
            
            let data = Data([
                0x18, 0x01, 0xbb, 0x08, 0x02, 0x11, 0x00, 0x00, 0x01, 0x05, 0x00, 0x00, 0x00, 0x0e, 0x4a, 0x47, 0x20, 0x54, 0x65, 0x73, 0x74, 0x20, 0x42, 0x72, 0x6f, 0x6b, 0x65, 0x72, 0x1e, 0x42, 0x72, 0x6f, 0x6b, 0x65, 0x72, 0x20, 0x64, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x69, 0x6f, 0x6e, 0x5c, 0x6e, 0x20, 0x67, 0x6f, 0x65, 0x73, 0x20, 0x68, 0x65, 0x72, 0x65, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01, 0x01, 0x00, 0x00, 0x09, 0x46, 0x72, 0x65, 0x65, 0x20, 0x50, 0x6c, 0x61, 0x79, 0x16, 0x52, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x20, 0x5a, 0x6f, 0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61, 0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xa9, 0x00, 0x32, 0x00, 0x32, 0x00, 0x64, 0x01, 0x02, 0x00, 0x00, 0x0f, 0x44, 0x69, 0x73, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x16, 0x52, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x20, 0x5a, 0x6f, 0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61, 0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xaa, 0x00, 0x32, 0x00, 0x32, 0x00, 0x64, 0x00, 0x03, 0x00, 0x00, 0x0b, 0x46, 0x75, 0x6c, 0x6c, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x16, 0x52, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x20, 0x5a, 0x6f, 0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61, 0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xab, 0x00, 0x64, 0x00, 0x64, 0x00, 0x64, 0x01, 0x04, 0x00, 0x00, 0x0f, 0x4c, 0x6f, 0x6f, 0x70, 0x62, 0x61, 0x63, 0x6b, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x14, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x68, 0x6f, 0x73, 0x74, 0x5c, 0x6e, 0x50, 0x6f, 0x72, 0x74, 0x20, 0x38, 0x33, 0x37, 0x30, 0x7f, 0x00, 0x00, 0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01
            ])
            
            let jsonString = #"""
                [{
                    "name": "JG Test Broker",
                    "description": "Broker description\\n goes here",
                    "address": "192.168.1.1",
                    "port": 8370,
                    "utilization": 0,
                    "capacity": 100,
                    "enabled": true
                }, {
                    "name": "Free Play",
                    "description": "Rookie Zone\\nAvatar ON",
                    "address": "192.168.1.1",
                    "port": 8361,
                    "utilization": 50,
                    "capacity": 100,
                    "enabled": true
                }, {
                    "name": "Disabled Server",
                    "description": "Rookie Zone\\nAvatar ON",
                    "address": "192.168.1.1",
                    "port": 8362,
                    "utilization": 50,
                    "capacity": 100,
                    "enabled": false
                }, {
                    "name": "Full Server",
                    "description": "Rookie Zone\\nAvatar ON",
                    "address": "192.168.1.1",
                    "port": 8363,
                    "utilization": 100,
                    "capacity": 100,
                    "enabled": true
                }, {
                    "name": "Loopback Server",
                    "description": "localhost\\nPort 8370",
                    "address": "127.0.0.1",
                    "port": 8370,
                    "utilization": 0,
                    "capacity": 100,
                    "enabled": true
                }]
            """#
            
            let jsonDecoder = JSONDecoder()
            let serverDirectory = try jsonDecoder.decode(ServerDirectory.self, from: Data(jsonString.utf8))
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 0x0118)
            XCTAssertEqual(packet.data.count, 280)
            XCTAssertEqual(packet.id, .init(serverPacketLength: 280))
            XCTAssertEqual(packet.id, 0x08BB)
            XCTAssertEqual(packet.opcode, .serverDirectoryResponse)
            XCTAssertEqual(packet.parametersSize, 280 - 6)
            
            XCTAssertEqual(serverDirectory.count, 5)
            XCTAssertEqual(serverDirectory[0].name, "JG Test Broker")
            XCTAssertEqual(serverDirectory[0].descriptionText, #"Broker description\n goes here"#)
            XCTAssertEncode(ServerDirectoryResponse(directory: serverDirectory), data)
        }
    }
    
    func testNonceRequest() {
        
        let data = Data([0x06, 0x00, 0xB1, 0x36, 0x00, 0x10])
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.opcode, .nonceRequest)
        XCTAssertEqual(packet.size, numericCast(Packet.minSize))
        XCTAssertEqual(packet.data.count, numericCast(Packet.minSize))
        XCTAssertEqual(packet.id, 0x36B1)
        XCTAssertEqual(packet.parametersSize, 0)
        
        XCTAssertDecodePacket(NonceRequest(), data)
    }
    
    func testNonceResponse() {
        
        let data = Data([0x0A, 0x00, 0xE5, 0x53, 0x01, 0x10, 0x2A, 0x0C, 0x11, 0x0A])
        let value = NonceResponse(nonce: 0x0A110C2A)
        XCTAssertEncode(value, id: 0x53E5, data)
    }
    
    func testLoginRequest() throws {
        
        let data = Data(hexString: "5600AF0D101015E9A289210936868CB9FADA26CB0C0B6932CC16C212E1E782457DDCD75E6542855F4B1102A6670C211C615FD886DFA72B0AB1164CC75A3DA8EBE5CBD3856EB75B47E9A28C2CA0A3A0ED467A12CBE942")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 86)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .authenticationRequest)
        
        var decoder = GunBoundDecoder()
        decoder.log = { print("Decoder:", $0) }
        
        let decodedValue = try decoder.decodePacket(AuthenticationRequest.self, from: data)
        XCTAssertEqual(decodedValue.username, "testusername")
        
        let key = Key(username: decodedValue.username, password: "testpassword", nonce: 0x00010203)
        let decryptedData = try Crypto.AES.decrypt(decodedValue.encryptedData, key: key, opcode: type(of: decodedValue).opcode)
        let decryptedValue = try decoder.decode(AuthenticationRequest.EncryptedData.self, from: decryptedData)
        
        XCTAssertEqual(decryptedValue.password, "testpassword")
        XCTAssertEqual(decryptedValue.clientVersion, 280)
    }
    
    func testLoginResponse() {
        
        let username = "testusername"
        let password = "testpassword"
        let nonce: Nonce = 0x37C654B2
        
        let data = Data(hexString: "A301FC9A12100000545D800974657374757365726E616D650100000001000300746573740000000014001400050D3905000039050000040D00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038900D0038900D003F420F00000000000000000000000000000000000000000400")!
        
        
    }
}

// MARK: - Extensions

extension Data {
    
    init?(hexString: String) {
      let len = hexString.count / 2
      var data = Data(capacity: len)
      var i = hexString.startIndex
      for _ in 0..<len {
        let j = hexString.index(i, offsetBy: 2)
        let bytes = hexString[i..<j]
        if var num = UInt8(bytes, radix: 16) {
          data.append(&num, count: 1)
        } else {
          return nil
        }
        i = j
      }
      self = data
    }
}

func XCTAssertEncode<T>(
    _ value: T,
    id: Packet.ID? = nil,
    _ data: Data,
    file: StaticString = #file,
    line: UInt = #line
) where T: Equatable, T: Encodable, T: GunBoundPacket {
    
    var encoder = GunBoundEncoder()
    encoder.log = { print("Encoder:", $0) }
    
    do {
        let packet = try encoder.encode(value, id: id)
        XCTAssertFalse(packet.data.isEmpty, file: file, line: line)
        XCTAssertEqual(packet.data, data, "\(packet.data.hexString) is not equal to \(data.hexString)", file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription, file: file, line: line)
        dump(error)
    }
}

func XCTAssertDecodePacket<T>(_ value: T, _ data: Data, file: StaticString = #file, line: UInt = #line) where T: GunBoundPacket, T: Equatable, T: Decodable {
    
    var decoder = GunBoundDecoder()
    decoder.log = { print("Decoder:", $0) }
    
    do {
        let decodedValue = try decoder.decodePacket(T.self, from: data)
        XCTAssertEqual(decodedValue, value, file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription, file: file, line: line)
        dump(error)
    }
}
