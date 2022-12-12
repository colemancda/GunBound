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
        
        let value = ServerDirectoryRequest()
        XCTAssertEncode(value, packet)
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
            
            let value = ServerDirectoryResponse(directory: serverDirectory)
            XCTAssertEncode(value, packet)
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
            
            let value = ServerDirectoryResponse(directory: serverDirectory)
            XCTAssertEncode(value, packet)
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
        XCTAssertDecode(NonceRequest(), packet)
    }
    
    func testNonceResponse() {
        
        let data = Data(hexString: "0A00E553011000010203")!
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.opcode, .nonceResponse)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.id, 0x53E5)
        
        let value = NonceResponse(nonce: 0x00010203)
        XCTAssertEncode(value, packet)
    }
    
    func testLoginRequest() throws {
        
        var decoder = GunBoundDecoder()
        decoder.log = { print("Decoder:", $0) }
        
        do {
            let data = Data(hexString: "5600AF0D101015E9A289210936868CB9FADA26CB0C0BAAE7BFEBC24041E8BDB5D88036C22C22B714950242A6420520009FB4D5982F206B95BFE48F126A515F6E33136935548222053C9135FFCB7742D8DFBD0AE23082")!
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 86)
            XCTAssertEqual(packet.size, numericCast(packet.data.count))
            XCTAssertEqual(packet.opcode, .authenticationRequest)
            XCTAssertEqual(packet.id, 0x0DAF)
            
            let decodedValue = try decoder.decodePacket(AuthenticationRequest.self, from: data)
            XCTAssertEqual(decodedValue.username, "testusername")
            
            let key = Key(username: decodedValue.username, password: "testpassword", nonce: 0xEA7B8AE3)
            let decryptedData = try Crypto.AES.decrypt(decodedValue.encryptedData, key: key, opcode: type(of: decodedValue).opcode)
            let decryptedValue = try decoder.decode(AuthenticationRequest.EncryptedData.self, from: decryptedData)
            
            XCTAssertEqual(decryptedValue.password, "testpassword")
            XCTAssertEqual(decryptedValue.clientVersion, 280)
        }
        
        do {
            let data = Data(hexString: "5600AF0D101015E9A289210936868CB9FADA26CB0C0B6932CC16C212E1E782457DDCD75E6542855F4B1102A6670C211C615FD886DFA72B0AB1164CC75A3DA8EBE5CBD3856EB75B47E9A28C2CA0A3A0ED467A12CBE942")!
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 86)
            XCTAssertEqual(packet.size, numericCast(packet.data.count))
            XCTAssertEqual(packet.opcode, .authenticationRequest)
            
            let decodedValue = try decoder.decodePacket(AuthenticationRequest.self, from: data)
            XCTAssertEqual(decodedValue.username, "testusername")
            
            let key = Key(username: decodedValue.username, password: "testpassword", nonce: 0x00010203)
            let decryptedData = try Crypto.AES.decrypt(decodedValue.encryptedData, key: key, opcode: type(of: decodedValue).opcode)
            let decryptedValue = try decoder.decode(AuthenticationRequest.EncryptedData.self, from: decryptedData)
            
            XCTAssertEqual(decryptedValue.password, "testpassword")
            XCTAssertEqual(decryptedValue.clientVersion, 280)
        }
    }
    
    func testLoginResponse() throws {
        
        var encoder = GunBoundEncoder()
        encoder.log = { print("Encoder:", $0) }
        
        let data = Data(hexString: "A301FC9A12100000698C621461646D696E0000000000000000800080008000007669727475616C0014001400050D3905000039050000040D00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038900D0038900D003F420F00000000000000000000000000000000000000000400")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 419)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .authenticationResponse)
        
        let value = AuthenticationResponse(userData:
            AuthenticationResponse.UserData(
                session: 0x698C6214,
                username: "admin",
                avatarEquipped: UInt64(0x0080008000800000).bigEndian,
                guild: "virtual",
                rankCurrent: 20,
                rankSeason: 20,
                guildMemberCount: 3333,
                rankPositionCurrent: 1337,
                rankPositionSeason: 1337,
                guildRank: 3332,
                gpCurrent: 888888,
                gpSeason: 888888,
                gold: 99_9999,
                funcRestrict: [.effectMoon]
            )
        )
        
        XCTAssertEncode(value, packet)
    }
    
    func testCashUpdate() {
        
        let data = Data(hexString: "1600BA723210A791BE6CECA91C106A641B509550A630")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 22)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .cashUpdateNotification)
        
        let value = CashUpdate(cash: 99_9999)
        
        let key = Key(
            username: "admin",
            password: "1234",
            nonce: 0x00010203
        )
                
        XCTAssertEncode(value, packet, key: key)
    }
    
    func testJoinChannelRequest() {
        
        let data = Data([0x08, 0x00, 0x97, 0x2D, 0x00, 0x20, 0xFF, 0xFF])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 8)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .joinChannelRequest)
        XCTAssertEqual(packet.id, 0x2D97)
        
        let value = JoinChannelRequest(
            channel: 0xFFFF
        )
        
        XCTAssertDecode(value, packet)
    }
    
    func testJoinChannelResponse() {
        
        let data = Data(hexString: "3100277601200000000000010061646D696E0000000000000000800080008000007669727475616C00140014006D6F7464")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 49)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .joinChannelResponse)
        XCTAssertEqual(packet.id, 0x7627)
        
        let value = JoinChannelResponse(
            status: 0x0000,
            channel: 0,
            maxPosition: 0,
            users: [
                JoinChannelResponse.ChannelUser(
                    id: 0,
                    username: "admin",
                    avatarEquipped: UInt64(0x0080008000800000).bigEndian,
                    guild: "virtual",
                    rankCurrent: 20,
                    rankSeason: 20
                )
            ],
            message: "motd"
        )
        
        XCTAssertEncode(value, packet)
    }
    
    func testJoinChannelNotification() {
        
        let data = Data([0x27, 0x00, 0xC2, 0x0A, 0x0E, 0x20, 0x00, 0x61, 0x64, 0x6D, 0x69, 0x6E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 39)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .joinChannelNotification)
        XCTAssertEqual(packet.id, 0x0AC2)
        
        let value = JoinChannelNotification(
            channelPosition: 0,
            username: "admin",
            avatarEquipped: 140739635871744,
            guild: "",
            rankCurrent: 0,
            rankSeason: 0
        )
        
        XCTAssertEncode(value, packet)
    }
    
    func testRoomListRequest() {
        
        do {
            let data = Data([0x0A, 0x00, 0x79, 0xD5, 0x00, 0x21, 0x02, 0x00, 0x00, 0x00])
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 10)
            XCTAssertEqual(packet.size, numericCast(packet.data.count))
            XCTAssertEqual(packet.opcode, .roomListRequest)
            XCTAssertEqual(packet.id, 0xD579)
            
            let value = RoomListRequest(filter: .waiting)
            
            XCTAssertDecode(value, packet)
        }
                
        do {
            let data = Data(hexString: "0A002BBD002101000000")!
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 10)
            XCTAssertEqual(packet.size, numericCast(packet.data.count))
            XCTAssertEqual(packet.opcode, .roomListRequest)
            XCTAssertEqual(packet.id, 0xBD2B)
            
            let value = RoomListRequest(filter: .all)
            
            XCTAssertDecode(value, packet)
        }
    }
    
    func testRoomListResponse() {
        
        do {
            let data = Data(hexString: "0A00D1B9032100000000")!
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 10)
            XCTAssertEqual(packet.size, numericCast(packet.data.count))
            XCTAssertEqual(packet.opcode, .roomListResponse)
            XCTAssertEqual(packet.id, 0xB9D1)
            
            let value: RoomListResponse = []
            XCTAssertEncode(value, packet)
        }
        
        do {
            let data = Data(hexString: "23005FD403210000010000000D61646D696E207669727475616C00B2620C0001020000")!
            
            guard let packet = Packet(data: data) else {
                XCTFail()
                return
            }
            XCTAssertEqual(packet.data, data)
            XCTAssertEqual(packet.size, 35)
            XCTAssertEqual(packet.size, numericCast(packet.data.count))
            XCTAssertEqual(packet.opcode, .roomListResponse)
            XCTAssertEqual(packet.id, 0xD45F)
            
            let value: RoomListResponse = [
                RoomListResponse.Room(
                    id: 0,
                    name: "admin virtual",
                    map: .random,
                    settings: UInt32(0xB2620C00).bigEndian,
                    playerCount: 1,
                    capacity: 2,
                    isPlaying: false,
                    isLocked: false
                )
            ]
            XCTAssertEncode(value, packet)
        }
    }
    
    func testJoinRoomRequest() {
        
        let data = Data([0x0C, 0x00, 0x55, 0x05, 0x10, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 12)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .joinRoomRequest)
        XCTAssertEqual(packet.id, 0x0555)
        
        let value = JoinRoomRequest(room: 0)
        XCTAssertEqual(value.password, "")
        XCTAssertEqual(value.password.rawValue, "")
        
        XCTAssertDecode(value, packet)
        XCTAssertEncode(value, packet)
    }
    
    func testJoinRoomResponse() {
        
        let data = Data(hexString: "8C000EFA1121000000010100047465737400B2620000FFFFFFFFFFFFFFFF08020061646D696E00000000000000C0A8017720ABC0A8017720AB0CFF000101000000010003007669727475616C001400140001636F6C656D616E6364610000C0A801C020ABC0A801C020ABFFFF0101000000000000000000000000000000001400140024526F6F6D204D4F5444")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 140)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .joinRoomResponse)
        XCTAssertEqual(packet.id, 0xFA0E)
                
        /*
         Room ID 1
         Room name test
         Map 0
         Settings b2b0000
         Session IP 192.168.1.119
         Port 20AB
         Room slot 0
         Avatar 0100000001000300
         Session IP 192.168.1.192
         Port 20AB
         Room slot 1
         Avatar 0000000000000000
         */
        let value = JoinRoomResponse(
            rtc: 0x0000,
            value0: 0x0100,
            room: 1,
            name: "test",
            map: .random,
            settings: UInt32(0xB2620000).bigEndian,
            value1: 0xFFFFFFFFFFFFFFFF,
            capacity: 8,
            players: [
                JoinRoomResponse.PlayerSession(
                    id: 0x00,
                    username: "admin",
                    address: GunBoundAddress(rawValue: "192.168.1.119:8363")!,
                    address2: GunBoundAddress(rawValue: "192.168.1.119:8363")!,
                    primaryTank: .grub,
                    secondary: .random,
                    team: .a,
                    value0: 0x01,
                    avatarEquipped: UInt64(0x0100000001000300).bigEndian,
                    guild: "virtual",
                    rankCurrent: 20,
                    rankSeason: 20
                ),
                JoinRoomResponse.PlayerSession(
                    id: 0x01,
                    username: "colemancda",
                    address: GunBoundAddress(rawValue: "192.168.1.192:8363")!,
                    address2: GunBoundAddress(rawValue: "192.168.1.192:8363")!,
                    primaryTank: .random,
                    secondary: .random,
                    team: .b,
                    value0: 0x01,
                    avatarEquipped: 0x0000000000000000,
                    guild: "",
                    rankCurrent: 20,
                    rankSeason: 20
                )
            ],
            message: "$Room MOTD"
        )
        
        XCTAssertEncode(value, packet)
    }
    
    func testJoinRoomNotification() {
        
        let data = Data(hexString: "36007EBF103001636F6C656D616E6364610000C0A801C020ABC0A801C020ABFFFF010000000000000000000000000000000014001400")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 54)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .joinRoomNotification)
        XCTAssertEqual(packet.id, 0xBF7E)
        
        let value = JoinRoomNotification(
            id: 0x01,
            username: "colemancda",
            address: GunBoundAddress(rawValue: "192.168.1.192:8363")!,
            address2: GunBoundAddress(rawValue: "192.168.1.192:8363")!,
            primaryTank: .random,
            secondary: .random,
            team: .b,
            avatarEquipped: 0x0000000,
            guild: "",
            rankCurrent: 20,
            rankSeason: 20
        )
        
        XCTAssertDecode(value, packet)
        XCTAssertEncode(value, packet)
    }
    
    func testJoinRoomNotificationSelf() {
        
        let data = Data(hexString: "09001695F521000003")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 9)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .joinRoomNotificationSelf)
        XCTAssertEqual(packet.id, 0x9516)
        
        let value = JoinRoomNotificationSelf()
        XCTAssertEncode(value, packet)
    }
    
    func testCreateRoomRequest() {
        
        let data = Data(hexString: "14003D2520210474657374B26200003132333408")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 20)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .createRoomRequest)
        XCTAssertEqual(packet.id, 0x253D)
        
        // Creating room test with password 1234 playing SOLO for 8 players.
        let value = CreateRoomRequest(
            name: "test",
            settings: 25266,
            password: "1234",
            capacity: 8
        )
        
        XCTAssertDecode(value, packet)
    }
    
    func testCreateRoomResponse() {
        
        let data = Data(hexString: "150020682121000000010024526F6F6D204D4F5444")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 21)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .createRoomResponse)
        XCTAssertEqual(packet.id, 0x6820)
        
        let value = CreateRoomResponse(
            room: 1,
            message: "$Room MOTD"
        )
        
        XCTAssertEncode(value, packet)
    }
    
    func testRoomSelectTankRequest() {
        
        let data = Data([0x08, 0x00, 0x2E, 0x79, 0x00, 0x32, 0x04, 0xFF])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 8)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomSelectTankRequest)
        XCTAssertEqual(packet.id, 0x792E)
        
        let value = RoomSelectTankRequest(
            primary: .bigFoot,
            secondary: .random
        )
        
        XCTAssertEncode(value, packet)
        XCTAssertDecode(value, packet)
    }
    
    func testRoomSelectTankResponse() {
        
        let data = Data([0x08, 0x00, 0xC3, 0xA3, 0x01, 0x32, 0x00, 0x00])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 8)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomSelectTankResponse)
        XCTAssertEqual(packet.id, 0xA3C3)
        
        let value = RoomSelectTankResponse()
        XCTAssertEncode(value, packet)
        XCTAssertDecode(value, packet)
    }
    
    func testRoomSelectTeamRequest() {
        
        let data = Data([0x07, 0x00, 0xD4, 0x70, 0x10, 0x32, 0x01])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 7)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomSelectTeamRequest)
        XCTAssertEqual(packet.id, 0x70D4)
        
        let value = RoomSelectTeamRequest(team: .b)
        XCTAssertEncode(value, packet)
        XCTAssertDecode(value, packet)
    }
    
    func testRoomChangeStageCommand() {
        
        let data = Data([0x07, 0x00, 0x07, 0xED, 0x00, 0x31, 0x01])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 7)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomChangeStageCommand)
        XCTAssertEqual(packet.id, 0xED07)
        
        let value = RoomChangeStageCommand(map: .miramoTown)
        XCTAssertEncode(value, packet)
        XCTAssertDecode(value, packet)
    }
    
    func testRoomChangeOptionCommand() {
        
        // Change Room Options - 004462B2
        let data = Data([0x0A, 0x00, 0x10, 0x21, 0x01, 0x31, 0xB2, 0x62, 0x44, 0x00])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 10)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomChangeOptionCommand)
        XCTAssertEqual(packet.id, 0x2110)
        
        let value = RoomChangeOptionCommand(settings: 0x004462B2)
        XCTAssertEncode(value, packet)
        XCTAssertDecode(value, packet)
    }
    
    func testRoomChangeCapacityCommand() {
        
        // Recieved packet roomChangeCapacity ID 0x792E
        let data = Data([0x07, 0x00, 0x2E, 0x79, 0x03, 0x31, 0x02])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 7)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomChangeCapacityCommand)
        XCTAssertEqual(packet.id, 0x792E)
        
        let value = RoomChangeCapacityCommand(capacity: 2)
        XCTAssertEncode(value, packet)
        XCTAssertDecode(value, packet)
    }
    
    func testRoomSetTitleCommand() {
        
        // Recieved packet roomSetTitleCommand ID 0x8922
        let data = Data([0x0B, 0x00, 0x22, 0x89, 0x04, 0x31, 0x68, 0x69, 0x31, 0x32, 0x33])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 11)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomSetTitleCommand)
        XCTAssertEqual(packet.id, 0x8922)
        
        let value = RoomSetTitleCommand(title: "hi123")
        XCTAssertDecode(value, packet)
    }
    
    func testUserReadyRequest() {
        
        // SVC_ROOM_USER_READY 1
        let data = Data([0x07, 0x00, 0x28, 0x01, 0x30, 0x32, 0x01])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 7)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomUserReadyRequest)
        XCTAssertEqual(packet.id, 0x0128)
        
        let value = UserReadyRequest(isReady: true)
        XCTAssertDecode(value, packet)
    }
    
    func testUserReadyResponse() {
        
        //
        let data = Data(hexString: "08005AE331320000")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 8)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomUserReadyResponse)
        XCTAssertEqual(packet.id, 0xE35A)
        
        let value = UserReadyResponse()
        XCTAssertEncode(value, packet)
    }
    
    func testChannelChatCommand() {
        
        let data = Data(hexString: "160037AD1020B9ED2802B33711762492AE38FF2DD39C")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 22)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .channelChatCommand)
        XCTAssertEqual(packet.id, 0xAD37)
        
        let message = "hi test"
        let key = Key(
            username: "colemancda",
            password: "1234",
            nonce: 0x00010203
        )
        
        let value = ChannelChatCommand(message: message)
        XCTAssertDecode(value, packet, key: key)
    }
    
    func testChannelChatBroadcast() {
        
        let data = Data(hexString: "2600C65F1F2042896EF758AF8ED739E8B5D10AA5FA588080ACAAA1BBBDF08C561A631B3596E1")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 38)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .channelChatBroadcast)
        XCTAssertEqual(packet.id, 0x5FC6)
        
        let key = Key(
            username: "colemancda",
            password: "1234",
            nonce: 0x00010203
        )
        
        let value = ChannelChatBroadcast(
            position: 0x01,
            username: "colemancda",
            message: "hi test"
        )
        
        XCTAssertEncode(value, packet, key: key)
    }
    
    func testClientCommand() {
        
        let data = Data([0x0E, 0x00, 0x4F, 0x8D, 0x00, 0x51, 0x2F, 0x74, 0x65, 0x73, 0x74, 0x20, 0x68, 0x69])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 14)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .clientCommand)
        XCTAssertEqual(packet.id, 0x8D4F)
        
        let value = ClientGenericCommand(
            value0: 0x2F,
            command: "test hi"
        )
        XCTAssertDecode(value, packet)
    }
    
    func testUserDeathRequest() {
        
        let data = Data(hexString: "0B00BF4C00410100000000")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 11)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .userDeadRequest)
        XCTAssertEqual(packet.opcode.type, .request)
        XCTAssertEqual(packet.opcode.response, .userDeadResponse)
        XCTAssertEqual(packet.id, 0x4CBF)
        
        let value = UserDeathRequest(
            value0: 01,
            value1: 0x00000000
        )
        XCTAssertDecode(value, packet)
    }
    
    func testUserDeadResponse() {
        
        let data = Data(hexString: "060030A40141")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 6)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .userDeadResponse)
        XCTAssertEqual(packet.opcode.type, .response)
        XCTAssertEqual(packet.opcode.request, .userDeadRequest)
        XCTAssertEqual(packet.id, 0xA430)
        
        let value = UserDeathResponse()
        XCTAssertEncode(value, packet)
    }
    
    func testStartGameCommand() {
        
        let data = Data(hexString: "0A0004313034F6749000")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 10)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .startGameCommand)
        XCTAssertEqual(packet.opcode.type, .command)
        XCTAssertEqual(packet.id, 0x3104)
        
        let value = StartGameCommand(
            value0: UInt32(0xF6749000).bigEndian
        )
        XCTAssertDecode(value, packet)
        XCTAssertEncode(value, packet)
    }
    
    func testStartGameNotification() {
        
        /*
         Map Side A
         Spawn order / slot: [0, 3, 4, 7, 5, 6, 1, 2]
         Turn order / slot: [0, 1]
         x: 253 y 0
         x: 936 y 0
         */
        
        let data = Data(hexString: "5600017A3234A34D16EBFBA6F065ACC095DEA8FEB8356893D0E6E4A889D997E8CF18BEE510BE396B45F40AD9D2A62015DBBE6359208B16F7630BC23041311B1EF4DB1B74E729816BD533773BC813DA67AF8C392FD2EC")!
        let plainText = Data(hexString: "00020000636F6C656D616E6364610000000408FD00000000000161646D696E00000000000000010107A8030000010000FFF6749000")!
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 86)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .startGameNotification)
        XCTAssertEqual(packet.opcode.type, .notification)
        XCTAssertEqual(packet.id, 0x7A01)
        
        let key = Key(
            username: "colemancda",
            password: "1234",
            nonce: 0x00010203
        )
                
        let value = StartGameNotification(
            map: .random,
            players: [
                StartGameNotification.Player(
                    id: 0x00,
                    username: "admin",
                    team: .a,
                    primaryTank: .random,
                    secondaryTank: .random,
                    xPosition: 253,
                    yPosition: 0,
                    turnOrder: 0
                ),
                StartGameNotification.Player(
                    id: 0x01,
                    username: "colemancda",
                    team: .b,
                    primaryTank: .random,
                    secondaryTank: .random,
                    xPosition: 936,
                    yPosition: 0,
                    turnOrder: 1
                )
            ],
            events: 0xFF00,
            commandData: UInt32(0xF6749000).bigEndian
        )
        
        let plainTextPacket = Packet(opcode: packet.opcode, id: packet.id, parameters: plainText)
        XCTAssertEqual(try plainTextPacket.encrypt(key: key), packet)
        //XCTAssertDecodeDecrypted(value, plainTextPacket)
        //XCTAssertEncodeDecrypted(value, plainTextPacket)
        //XCTAssertEncode(value, packet, key: key)
        //XCTAssertDecode(value, packet, key: key)
    }
    
    func testRoomReturnResultRequest() {
        
        let data = Data([0x06, 0x00, 0xA1, 0xF4, 0x32, 0x32])
        
        guard let packet = Packet(data: data) else {
            XCTFail()
            return
        }
        XCTAssertEqual(packet.data, data)
        XCTAssertEqual(packet.size, 6)
        XCTAssertEqual(packet.size, numericCast(packet.data.count))
        XCTAssertEqual(packet.opcode, .roomReturnResultRequest)
        XCTAssertEqual(packet.opcode.type, .request)
        XCTAssertEqual(packet.id, 0xF4A1)
        
        let value = RoomReturnResultRequest()
        XCTAssertDecode(value, packet)
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
    _ packet: Packet,
    key: Key? = nil,
    file: StaticString = #file,
    line: UInt = #line
) where T: Equatable, T: Encodable, T: GunBoundPacket {
    
    var encoder = GunBoundEncoder()
    encoder.log = { print("Encoder:", $0) }
    
    do {
        var encodedPacket = try encoder.encode(value, id: packet.id)
        XCTAssertFalse(encodedPacket.data.isEmpty, file: file, line: line)
        if T.opcode.isEncrypted {
            guard let key = key else {
                throw GunBoundError.notAuthenticated
            }
            encodedPacket = try encodedPacket.encrypt(key: key)
        }
        XCTAssertEqual(encodedPacket.data, packet.data, "\(encodedPacket.data.hexString) is not equal to \(packet.data.hexString)", file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription, file: file, line: line)
        dump(error)
    }
}


func XCTAssertEncodeDecrypted<T>(
    _ value: T,
    _ packet: Packet,
    file: StaticString = #file,
    line: UInt = #line
) where T: Equatable, T: Encodable, T: GunBoundPacket {
    
    var encoder = GunBoundEncoder()
    encoder.log = { print("Encoder:", $0) }
    
    do {
        let encodedPacket = try encoder.encode(value, id: packet.id)
        XCTAssertFalse(encodedPacket.data.isEmpty, file: file, line: line)
        XCTAssertEqual(encodedPacket.data, packet.data, "\(encodedPacket.data.hexString) is not equal to \(packet.data.hexString)", file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription, file: file, line: line)
        dump(error)
    }
}

func XCTAssertDecode<T>(
    _ value: T,
    _ packet: Packet,
    key: Key? = nil,
    file: StaticString = #file,
    line: UInt = #line
) where T: GunBoundPacket, T: Equatable, T: Decodable {
    
    var decoder = GunBoundDecoder()
    decoder.log = { print("Decoder:", $0) }
    
    do {
        var packet = packet
        if T.opcode.isEncrypted {
            guard let key = key else {
                throw GunBoundError.notAuthenticated
            }
            packet = try packet.decrypt(key: key)
        }
        let decodedValue = try decoder.decodePacket(T.self, from: packet.data)
        XCTAssertEqual(decodedValue, value, file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription, file: file, line: line)
        dump(error)
    }
}

func XCTAssertDecodeDecrypted<T>(
    _ value: T,
    _ packet: Packet,
    file: StaticString = #file,
    line: UInt = #line
) where T: GunBoundPacket, T: Equatable, T: Decodable {
    
    var decoder = GunBoundDecoder()
    decoder.log = { print("Decoder:", $0) }
    
    do {
        let decodedValue = try decoder.decodePacket(T.self, from: packet.data)
        XCTAssertEqual(decodedValue, value, file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription, file: file, line: line)
        dump(error)
    }
}
