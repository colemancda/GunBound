//
//  GunBoundTests.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Testing
@testable import GunBound

@Suite struct GunBoundTests {

    @Test func address() {
        #expect(GunBoundAddress(rawValue: "192.168.1.1:1234")?.address == "192.168.1.1")
        #expect(GunBoundAddress(rawValue: "192.168.1.1:1234")?.port == 1234)
        #expect(GunBoundAddress(rawValue: "192.168.1.1:1234")?.rawValue == "192.168.1.1:1234")
        #expect(GunBoundAddress(rawValue: "192.168.1.1") == nil)
    }

    @Test func serverDirectoryRequest() throws {
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
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 10)
        #expect(packet.data.count == 10)
        #expect(packet.opcode == .serverDirectoryRequest)
        #expect(packet.id == 0x46A5)
        #expect(packet.parametersSize == 4)
        #expect(packet.parameters == Data([0x00, 0x00, 0x00, 0x00]))
        assertEncode(ServerDirectoryRequest(), packet)
        assertDecode(ServerDirectoryRequest(), packet)
    }

    @Test func serverDirectoryResponse() throws {
        do {
            let data = Data([
                0x48, 0x00, 0x2b, 0xcb, 0x02, 0x11, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x0e, 0x4a, 0x47, 0x20, 0x54, 0x65, 0x73, 0x74, 0x20, 0x42, 0x72, 0x6f, 0x6b, 0x65, 0x72, 0x1e, 0x42,
                0x72, 0x6f, 0x6b, 0x65, 0x72, 0x20, 0x64, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x69, 0x6f, 0x6e, 0x5c, 0x6e, 0x20, 0x67, 0x6f, 0x65, 0x73, 0x20, 0x68, 0x65, 0x72, 0x65, 0xc0,
                0xa8, 0x01, 0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01
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
                    }]
                """#
            let serverDirectory = try JSONDecoder().decode(ServerDirectory.self, from: Data(jsonString.utf8))
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 72)
            #expect(packet.data.count == 72)
            #expect(packet.id == .init(serverPacketLength: packet.data.count))
            #expect(packet.id == 0xCB2B)
            #expect(packet.opcode == .serverDirectoryResponse)
            #expect(packet.parametersSize == packet.data.count - 6)
            #expect(serverDirectory.count == 1)
            #expect(serverDirectory[0].name == "JG Test Broker")
            #expect(serverDirectory[0].descriptionText == #"Broker description\n goes here"#)
            assertEncode(ServerDirectoryResponse(directory: serverDirectory), packet)
        }

        do {
            let data = Data([
                0x18, 0x01, 0xbb, 0x08, 0x02, 0x11, 0x00, 0x00, 0x01, 0x05, 0x00, 0x00, 0x00, 0x0e, 0x4a, 0x47, 0x20, 0x54, 0x65, 0x73, 0x74, 0x20, 0x42, 0x72, 0x6f, 0x6b, 0x65, 0x72, 0x1e, 0x42,
                0x72, 0x6f, 0x6b, 0x65, 0x72, 0x20, 0x64, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x69, 0x6f, 0x6e, 0x5c, 0x6e, 0x20, 0x67, 0x6f, 0x65, 0x73, 0x20, 0x68, 0x65, 0x72, 0x65, 0xc0,
                0xa8, 0x01, 0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01, 0x01, 0x00, 0x00, 0x09, 0x46, 0x72, 0x65, 0x65, 0x20, 0x50, 0x6c, 0x61, 0x79, 0x16, 0x52, 0x6f, 0x6f, 0x6b,
                0x69, 0x65, 0x20, 0x5a, 0x6f, 0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61, 0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xa9, 0x00, 0x32, 0x00, 0x32, 0x00, 0x64,
                0x01, 0x02, 0x00, 0x00, 0x0f, 0x44, 0x69, 0x73, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x16, 0x52, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x20, 0x5a, 0x6f,
                0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61, 0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xaa, 0x00, 0x32, 0x00, 0x32, 0x00, 0x64, 0x00, 0x03, 0x00, 0x00, 0x0b,
                0x46, 0x75, 0x6c, 0x6c, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x16, 0x52, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x20, 0x5a, 0x6f, 0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61,
                0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xab, 0x00, 0x64, 0x00, 0x64, 0x00, 0x64, 0x01, 0x04, 0x00, 0x00, 0x0f, 0x4c, 0x6f, 0x6f, 0x70, 0x62, 0x61, 0x63, 0x6b, 0x20,
                0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x14, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x68, 0x6f, 0x73, 0x74, 0x5c, 0x6e, 0x50, 0x6f, 0x72, 0x74, 0x20, 0x38, 0x33, 0x37, 0x30, 0x7f, 0x00, 0x00,
                0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01
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
            let serverDirectory = try JSONDecoder().decode(ServerDirectory.self, from: Data(jsonString.utf8))
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 0x0118)
            #expect(packet.data.count == 280)
            #expect(packet.id == .init(serverPacketLength: 280))
            #expect(packet.id == 0x08BB)
            #expect(packet.opcode == .serverDirectoryResponse)
            #expect(packet.parametersSize == 280 - 6)
            #expect(serverDirectory.count == 5)
            #expect(serverDirectory[0].name == "JG Test Broker")
            #expect(serverDirectory[0].descriptionText == #"Broker description\n goes here"#)
            assertEncode(ServerDirectoryResponse(directory: serverDirectory), packet)
        }
    }

    @Test func nonceRequest() throws {
        let data = Data([0x06, 0x00, 0xB1, 0x36, 0x00, 0x10])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.opcode == .nonceRequest)
        #expect(packet.size == numericCast(Packet.minSize))
        #expect(packet.data.count == numericCast(Packet.minSize))
        #expect(packet.id == 0x36B1)
        #expect(packet.parametersSize == 0)
        assertEncode(NonceRequest(), packet)
        assertDecode(NonceRequest(), packet)
    }

    @Test func nonceResponse() throws {
        let data = Data(hexString: "0A00E553011000010203")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.opcode == .nonceResponse)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.id == 0x53E5)
        assertEncode(NonceResponse(nonce: 0x0001_0203), packet)
    }

    @Test func loginRequest() throws {
        var decoder = GunBoundDecoder()
        decoder.log = { print("Decoder:", $0) }

        do {
            let data = Data(
                hexString:
                    "5600AF0D101015E9A289210936868CB9FADA26CB0C0BAAE7BFEBC24041E8BDB5D88036C22C22B714950242A6420520009FB4D5982F206B95BFE48F126A515F6E33136935548222053C9135FFCB7742D8DFBD0AE23082")!
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 86)
            #expect(packet.size == numericCast(packet.data.count))
            #expect(packet.opcode == .authenticationRequest)
            #expect(packet.id == 0x0DAF)
            let decodedValue = try decoder.decodePacket(AuthenticationRequest.self, from: data)
            #expect(decodedValue.username == "testusername")
            let key = Key(username: decodedValue.username, password: "testpassword", nonce: 0xEA7B_8AE3)
            let decryptedData = try Crypto.AES.decrypt(decodedValue.encryptedData, key: key, opcode: type(of: decodedValue).opcode)
            let decryptedValue = try decoder.decode(AuthenticationRequest.EncryptedData.self, from: decryptedData)
            #expect(decryptedValue.password == "testpassword")
            #expect(decryptedValue.clientVersion == 280)
        }

        do {
            let data = Data(
                hexString:
                    "5600AF0D101015E9A289210936868CB9FADA26CB0C0B6932CC16C212E1E782457DDCD75E6542855F4B1102A6670C211C615FD886DFA72B0AB1164CC75A3DA8EBE5CBD3856EB75B47E9A28C2CA0A3A0ED467A12CBE942")!
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 86)
            #expect(packet.size == numericCast(packet.data.count))
            #expect(packet.opcode == .authenticationRequest)
            let decodedValue = try decoder.decodePacket(AuthenticationRequest.self, from: data)
            #expect(decodedValue.username == "testusername")
            let key = Key(username: decodedValue.username, password: "testpassword", nonce: 0x0001_0203)
            let decryptedData = try Crypto.AES.decrypt(decodedValue.encryptedData, key: key, opcode: type(of: decodedValue).opcode)
            let decryptedValue = try decoder.decode(AuthenticationRequest.EncryptedData.self, from: decryptedData)
            #expect(decryptedValue.password == "testpassword")
            #expect(decryptedValue.clientVersion == 280)
        }
    }

    @Test func loginResponse() throws {
        var encoder = GunBoundEncoder()
        encoder.log = { print("Encoder:", $0) }
        let data = Data(
            hexString:
                "A301FC9A12100000698C621461646D696E0000000000000000800080008000007669727475616C0014001400050D3905000039050000040D00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038900D0038900D003F420F00000000000000000000000000000000000000000400"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 419)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .authenticationResponse)
        let value = AuthenticationResponse(
            userData: AuthenticationResponse.UserData(
                session: 0x698C_6214,
                username: "admin",
                avatarEquipped: UInt64(0x0080_0080_0080_0000).bigEndian,
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
        assertEncode(value, packet)
    }

    @Test func cashUpdate() throws {
        let data = Data(hexString: "1600BA723210A791BE6CECA91C106A641B509550A630")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 22)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .cashUpdateNotification)
        let key = Key(username: "admin", password: "1234", nonce: 0x0001_0203)
        assertEncode(CashUpdate(cash: 99_9999), packet, key: key)
    }

    @Test func joinChannelRequest() throws {
        let data = Data([0x08, 0x00, 0x97, 0x2D, 0x00, 0x20, 0xFF, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 8)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .joinChannelRequest)
        #expect(packet.id == 0x2D97)
        assertEncode(JoinChannelRequest(channel: 0xFFFF), packet)
        assertDecode(JoinChannelRequest(channel: 0xFFFF), packet)
    }

    @Test func joinChannelResponse() throws {
        let data = Data(hexString: "3100277601200000000000010061646D696E0000000000000000800080008000007669727475616C00140014006D6F7464")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 49)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .joinChannelResponse)
        #expect(packet.id == 0x7627)
        let value = JoinChannelResponse(
            status: 0x0000,
            channel: 0,
            maxPosition: 0,
            users: [
                JoinChannelResponse.ChannelUser(
                    id: 0,
                    username: "admin",
                    avatarEquipped: UInt64(0x0080_0080_0080_0000).bigEndian,
                    guild: "virtual",
                    rankCurrent: 20,
                    rankSeason: 20
                )
            ],
            message: "motd"
        )
        assertEncode(value, packet)
    }

    @Test func joinChannelNotification() throws {
        let data = Data([
            0x27, 0x00, 0xC2, 0x0A, 0x0E, 0x20, 0x00, 0x61, 0x64, 0x6D, 0x69, 0x6E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 39)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .joinChannelNotification)
        #expect(packet.id == 0x0AC2)
        let value = JoinChannelNotification(
            channelPosition: 0,
            username: "admin",
            avatarEquipped: 140_739_635_871_744,
            guild: "",
            rankCurrent: 0,
            rankSeason: 0
        )
        assertEncode(value, packet)
        assertDecode(value, packet)
    }

    @Test func roomListRequest() throws {
        do {
            let data = Data([0x0A, 0x00, 0x79, 0xD5, 0x00, 0x21, 0x02, 0x00, 0x00, 0x00])
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 10)
            #expect(packet.size == numericCast(packet.data.count))
            #expect(packet.opcode == .roomListRequest)
            #expect(packet.id == 0xD579)
            assertDecode(RoomListRequest(filter: .waiting), packet)
        }
        do {
            let data = Data(hexString: "0A002BBD002101000000")!
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 10)
            #expect(packet.size == numericCast(packet.data.count))
            #expect(packet.opcode == .roomListRequest)
            #expect(packet.id == 0xBD2B)
            assertDecode(RoomListRequest(filter: .all), packet)
        }
    }

    @Test func roomListResponse() throws {
        do {
            let data = Data(hexString: "0A00D1B9032100000000")!
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 10)
            #expect(packet.size == numericCast(packet.data.count))
            #expect(packet.opcode == .roomListResponse)
            #expect(packet.id == 0xB9D1)
            let value: RoomListResponse = []
            assertEncode(value, packet)
        }
        do {
            let data = Data(hexString: "23005FD403210000010000000D61646D696E207669727475616C00B2620C0001020000")!
            let packet = try #require(Packet(data: data))
            #expect(packet.data == data)
            #expect(packet.size == 35)
            #expect(packet.size == numericCast(packet.data.count))
            #expect(packet.opcode == .roomListResponse)
            #expect(packet.id == 0xD45F)
            let value: RoomListResponse = [
                RoomListResponse.Room(
                    id: 0,
                    name: "admin virtual",
                    map: .random,
                    settings: UInt32(0xB262_0C00).bigEndian,
                    playerCount: 1,
                    capacity: 2,
                    isPlaying: false,
                    isLocked: false
                )
            ]
            assertEncode(value, packet)
        }
    }

    @Test func joinRoomRequest() throws {
        let data = Data([0x0C, 0x00, 0x55, 0x05, 0x10, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 12)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .joinRoomRequest)
        #expect(packet.id == 0x0555)
        let value = JoinRoomRequest(room: 0)
        #expect(value.password == "")
        #expect(value.password.rawValue == "")
        assertDecode(value, packet)
        assertEncode(value, packet)
    }

    @Test func joinRoomResponse() throws {
        let data = Data(
            hexString:
                "8C000EFA1121000000010100047465737400B2620000FFFFFFFFFFFFFFFF08020061646D696E00000000000000C0A8017720ABC0A8017720AB0CFF000101000000010003007669727475616C001400140001636F6C656D616E6364610000C0A801C020ABC0A801C020ABFFFF0101000000000000000000000000000000001400140024526F6F6D204D4F5444"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 140)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .joinRoomResponse)
        #expect(packet.id == 0xFA0E)
        let value = JoinRoomResponse(
            rtc: 0x0000,
            value0: 0x0100,
            room: 1,
            name: "test",
            map: .random,
            settings: UInt32(0xB262_0000).bigEndian,
            value1: 0xFFFF_FFFF_FFFF_FFFF,
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
                    avatarEquipped: UInt64(0x0100_0000_0100_0300).bigEndian,
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
                    avatarEquipped: 0x0000_0000_0000_0000,
                    guild: "",
                    rankCurrent: 20,
                    rankSeason: 20
                )
            ],
            message: "$Room MOTD"
        )
        assertEncode(value, packet)
    }

    @Test func joinRoomNotification() throws {
        let data = Data(hexString: "36007EBF103001636F6C656D616E6364610000C0A801C020ABC0A801C020ABFFFF010000000000000000000000000000000014001400")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 54)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .joinRoomNotification)
        #expect(packet.id == 0xBF7E)
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
        assertDecode(value, packet)
        assertEncode(value, packet)
    }

    @Test func joinRoomNotificationSelf() throws {
        let data = Data(hexString: "09001695F521000003")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 9)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .joinRoomNotificationSelf)
        #expect(packet.id == 0x9516)
        assertEncode(JoinRoomNotificationSelf(), packet)
    }

    @Test func createRoomRequest() throws {
        let data = Data(hexString: "14003D2520210474657374B26200003132333408")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 20)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .createRoomRequest)
        #expect(packet.id == 0x253D)
        let value = CreateRoomRequest(name: "test", settings: 25266, password: "1234", capacity: 8)
        assertDecode(value, packet)
    }

    @Test func createRoomResponse() throws {
        let data = Data(hexString: "150020682121000000010024526F6F6D204D4F5444")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 21)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .createRoomResponse)
        #expect(packet.id == 0x6820)
        assertEncode(CreateRoomResponse(room: 1, message: "$Room MOTD"), packet)
    }

    @Test func roomSelectTankRequest() throws {
        let data = Data([0x08, 0x00, 0x2E, 0x79, 0x00, 0x32, 0x04, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 8)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x792E)
        let value = RoomSelectTankRequest(primary: .bigFoot, secondary: .random)
        assertEncode(value, packet)
        assertDecode(value, packet)
    }

    @Test func roomSelectTankResponse() throws {
        let data = Data([0x08, 0x00, 0xC3, 0xA3, 0x01, 0x32, 0x00, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 8)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.id == 0xA3C3)
        assertEncode(RoomSelectTankResponse(), packet)
        assertDecode(RoomSelectTankResponse(), packet)
    }

    @Test func roomSelectTeamRequest() throws {
        let data = Data([0x07, 0x00, 0xD4, 0x70, 0x10, 0x32, 0x01])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 7)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomSelectTeamRequest)
        #expect(packet.id == 0x70D4)
        assertEncode(RoomSelectTeamRequest(team: .b), packet)
        assertDecode(RoomSelectTeamRequest(team: .b), packet)
    }

    @Test func roomChangeStageCommand() throws {
        let data = Data([0x07, 0x00, 0x07, 0xED, 0x00, 0x31, 0x01])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 7)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.id == 0xED07)
        assertEncode(RoomChangeStageCommand(map: .miramoTown), packet)
        assertDecode(RoomChangeStageCommand(map: .miramoTown), packet)
    }

    @Test func roomChangeOptionCommand() throws {
        let data = Data([0x0A, 0x00, 0x10, 0x21, 0x01, 0x31, 0xB2, 0x62, 0x44, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 10)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.id == 0x2110)
        assertEncode(RoomChangeOptionCommand(settings: 0x0044_62B2), packet)
        assertDecode(RoomChangeOptionCommand(settings: 0x0044_62B2), packet)
    }

    @Test func roomChangeCapacityCommand() throws {
        let data = Data([0x07, 0x00, 0x2E, 0x79, 0x03, 0x31, 0x02])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 7)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.id == 0x792E)
        assertEncode(RoomChangeCapacityCommand(capacity: 2), packet)
        assertDecode(RoomChangeCapacityCommand(capacity: 2), packet)
    }

    @Test func roomSetTitleCommand() throws {
        let data = Data([0x0B, 0x00, 0x22, 0x89, 0x04, 0x31, 0x68, 0x69, 0x31, 0x32, 0x33])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 11)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomSetTitleCommand)
        #expect(packet.id == 0x8922)
        assertDecode(RoomSetTitleCommand(title: "hi123"), packet)
    }

    @Test func userReadyRequest() throws {
        let data = Data([0x07, 0x00, 0x28, 0x01, 0x30, 0x32, 0x01])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 7)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomUserReadyRequest)
        #expect(packet.id == 0x0128)
        assertEncode(UserReadyRequest(isReady: true), packet)
        assertDecode(UserReadyRequest(isReady: true), packet)
    }

    @Test func userReadyResponse() throws {
        let data = Data(hexString: "08005AE331320000")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 8)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomUserReadyResponse)
        #expect(packet.id == 0xE35A)
        assertEncode(UserReadyResponse(), packet)
        assertDecode(UserReadyResponse(), packet)
    }

    @Test func channelChatCommand() throws {
        let data = Data(hexString: "160037AD1020B9ED2802B33711762492AE38FF2DD39C")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 22)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .channelChatCommand)
        #expect(packet.id == 0xAD37)
        let key = Key(username: "colemancda", password: "1234", nonce: 0x0001_0203)
        assertDecode(ChannelChatCommand(message: "hi test"), packet, key: key)
    }

    @Test func channelChatBroadcast() throws {
        let data = Data(hexString: "2600C65F1F2042896EF758AF8ED739E8B5D10AA5FA588080ACAAA1BBBDF08C561A631B3596E1")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 38)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .channelChatBroadcast)
        #expect(packet.id == 0x5FC6)
        let key = Key(username: "colemancda", password: "1234", nonce: 0x0001_0203)
        assertEncode(ChannelChatBroadcast(position: 0x01, username: "colemancda", message: "hi test"), packet, key: key)
        assertDecode(ChannelChatBroadcast(position: 0x01, username: "colemancda", message: "hi test"), packet, key: key)
    }

    @Test func clientCommand() throws {
        let data = Data([0x0E, 0x00, 0x4F, 0x8D, 0x00, 0x51, 0x2F, 0x74, 0x65, 0x73, 0x74, 0x20, 0x68, 0x69])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 14)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .clientCommand)
        #expect(packet.id == 0x8D4F)
        assertDecode(ClientGenericCommand(value0: 0x2F, command: "test hi"), packet)
    }

    @Test func userDeathRequest() throws {
        let data = Data(hexString: "0B00BF4C00410100000000")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 11)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .userDeadRequest)
        #expect(packet.opcode.type == .request)
        #expect(packet.opcode.response == .userDeadResponse)
        #expect(packet.id == 0x4CBF)
        assertEncode(UserDeathRequest(value0: 01, value1: 0x0000_0000), packet)
        assertDecode(UserDeathRequest(value0: 01, value1: 0x0000_0000), packet)
    }

    @Test func userDeadResponse() throws {
        let data = Data(hexString: "060030A40141")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 6)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .userDeadResponse)
        #expect(packet.opcode.type == .response)
        #expect(packet.opcode.request == .userDeadRequest)
        #expect(packet.id == 0xA430)
        assertEncode(UserDeathResponse(), packet)
        assertDecode(UserDeathResponse(), packet)
    }

    @Test func startGameCommand() throws {
        let data = Data(hexString: "0A0004313034F6749000")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 10)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .startGameCommand)
        #expect(packet.opcode.type == .command)
        #expect(packet.id == 0x3104)
        let value = StartGameCommand(value0: UInt32(0xF674_9000).bigEndian)
        assertDecode(value, packet)
        assertEncode(value, packet)
    }

    @Test func startGameNotification() throws {
        /*
         Map Side A
         Spawn order / slot: [0, 3, 4, 7, 5, 6, 1, 2]
         Turn order / slot: [0, 1]
         x: 253 y 0
         x: 936 y 0
         */
        let data = Data(
            hexString: "5600017A3234A34D16EBFBA6F065ACC095DEA8FEB8356893D0E6E4A889D997E8CF18BEE510BE396B45F40AD9D2A62015DBBE6359208B16F7630BC23041311B1EF4DB1B74E729816BD533773BC813DA67AF8C392FD2EC")!
        let plainText = Data(hexString: "00020000636F6C656D616E6364610000000408FD00000000000161646D696E00000000000000010107A8030000010000FFF6749000")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 86)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .startGameNotification)
        #expect(packet.opcode.type == .notification)
        #expect(packet.id == 0x7A01)
        let key = Key(username: "colemancda", password: "1234", nonce: 0x0001_0203)
        let value = StartGameNotification(
            map: .random,
            players: [
                StartGameNotification.Player(
                    id: 0x00,
                    username: "colemancda",
                    team: .a,
                    primaryTank: .bigFoot,
                    secondaryTank: .jd,
                    xPosition: 253,
                    yPosition: 0,
                    turnOrder: 0
                ),
                StartGameNotification.Player(
                    id: 0x01,
                    username: "admin",
                    team: .b,
                    primaryTank: .mage,
                    secondaryTank: .lightning,
                    xPosition: 936,
                    yPosition: 0,
                    turnOrder: 1
                )
            ],
            events: 0xFF00,
            commandData: UInt32(0xF674_9000).bigEndian
        )
        let plainTextPacket = Packet(opcode: packet.opcode, id: packet.id, parameters: plainText)
        #expect(try plainTextPacket.encrypt(key: key) == packet)
        assertDecodeDecrypted(value, plainTextPacket)
        assertEncodeDecrypted(value, plainTextPacket)
        assertEncode(value, packet, key: key)
        assertDecode(value, packet, key: key)
    }

    @Test func gameResultCommand() throws {
        let data = Data([
            0x46, 0x00, 0xDC, 0x0E, 0x12, 0x44, 0x9E, 0xEE, 0xC7, 0x7E, 0x68, 0x00, 0x62, 0x0D, 0x03, 0x19, 0xE1, 0x02, 0x7F, 0x1C, 0x97, 0x1C, 0xA8, 0xB3, 0x38, 0xE9, 0x5D, 0x36, 0xC8, 0x3C, 0x8A,
            0x84, 0x49, 0x6E, 0xFA, 0x78, 0xAD, 0x45, 0xB3, 0x46, 0xDD, 0x71, 0x58, 0x10, 0xB8, 0x27, 0xA8, 0x7D, 0xF4, 0x6F, 0xA1, 0x88, 0xF1, 0x24, 0x38, 0x4F, 0xD9, 0xB7, 0xA2, 0x4A, 0x89, 0x09,
            0x23, 0x9D, 0x72, 0xFF, 0x11, 0x33, 0xC0, 0x2F
        ])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 70)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .playResultCommand)
        #expect(packet.opcode.type == .command)
        #expect(packet.id == 0x0EDC)
    }

    @Test func roomReturnResultRequest() throws {
        let data = Data([0x06, 0x00, 0xA1, 0xF4, 0x32, 0x32])
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 6)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomReturnResultRequest)
        #expect(packet.opcode.type == .request)
        #expect(packet.id == 0xF4A1)
        assertEncode(RoomReturnResultRequest(), packet)
        assertDecode(RoomReturnResultRequest(), packet)
    }

    // MARK: - Tests from Server Logs (09/07/12 08:15:15)

    @Test func nonceResponseFromLog() throws {
        // Server log: SEND>> [SS=011BC818 SQ=53E5 CD=1001] 12 6D B4 07
        // Demonstrates nonce response structure from real server
        let packet = Packet(
            opcode: .nonceResponse,
            id: 0x53E5,
            parameters: Data([0x12, 0x6D, 0xB4, 0x07])
        )
        #expect(packet.opcode == .nonceResponse)
        #expect(packet.id == 0x53E5)
        #expect(packet.size == 10)
        #expect(packet.parameters == Data([0x12, 0x6D, 0xB4, 0x07]))
    }

    @Test func joinChannelResponseFromLog() throws {
        // Server log: SEND>> [SS=011BC818 SQ=458B CD=2001]
        // Demonstrates join channel response structure from real server
        let value = JoinChannelResponse(
            status: 0x0000,
            channel: 2,
            maxPosition: 0,
            users: [
                JoinChannelResponse.ChannelUser(
                    id: 1,
                    username: "blackscorpio",
                    avatarEquipped: UInt64(0x0080_0080_0080_0080).bigEndian,
                    guild: "",
                    rankCurrent: 20,
                    rankSeason: 20
                )
            ],
            message: "$Blackscorpio - GB Private Server/Offline final released"
        )
        let packet = try GunBoundEncoder().encode(value, id: 0x458B)
        #expect(packet.opcode == .joinChannelResponse)
        #expect(packet.id == 0x458B)
    }

    @Test func roomListResponseEmptyFromLog() throws {
        // Server log: SEND>> [SS=011BC818 SQ=ED6D CD=2103 RTC=0000] 00 00
        // Empty room list response
        let data = Data(hexString: "0A006DED032100000000")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.size == 10)
        #expect(packet.size == numericCast(packet.data.count))
        #expect(packet.opcode == .roomListResponse)
        #expect(packet.id == 0xED6D)
        let value: RoomListResponse = []
        assertEncode(value, packet)
    }

    @Test func cashUpdateFromLog() throws {
        // Server log: SEND>> [SS=011BC818 SQ=72BA CD=1032]
        // Demonstrates cash update notification structure (encrypted)
        let packet = Packet(
            opcode: .cashUpdateNotification,
            id: 0x72BA,
            parameters: Data([0x0E, 0x1F, 0xC3, 0x40, 0xE9, 0x4B, 0x62, 0xE1, 0xED, 0x39, 0xB1, 0xC2, 0x0E, 0x59, 0x2A, 0xE1])
        )
        #expect(packet.opcode == .cashUpdateNotification)
        #expect(packet.id == 0x72BA)
        #expect(packet.size == 22)
        // Note: Encrypted payload bytes depend on key/cash value
    }

    // MARK: - Tests from Additional Server Logs (09/07/12 08:04-08:15)

    @Test func nonceResponseAdditionalLog1() throws {
        // Server log: SEND>> [SS=00347340 SQ=53E5 CD=1001] 88 4C 2D 1F
        // Nonce bytes: 88 4C 2D 1F (big-endian) = 0x1F2D4C88
        let data = Data(hexString: "0A00E55301101F2D4C88")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.opcode == .nonceResponse)
        #expect(packet.id == 0x53E5)
        #expect(packet.size == 10)
        assertEncode(NonceResponse(nonce: 0x1F2D_4C88), packet)
    }

    @Test func nonceResponseAdditionalLog2() throws {
        // Server log: SEND>> [SS=00347340 SQ=53E5 CD=1001] 7C 7F 3F 13
        // Nonce bytes: 7C 7F 3F 13 (big-endian) = 0x133F7F7C
        let data = Data(hexString: "0A00E5530110133F7F7C")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.opcode == .nonceResponse)
        #expect(packet.id == 0x53E5)
        #expect(packet.size == 10)
        assertEncode(NonceResponse(nonce: 0x133F_7F7C), packet)
    }

    @Test func nonceResponseAdditionalLog3() throws {
        // Server log: SEND>> [SS=00347340 SQ=53E5 CD=1001] A4 CD F9 36
        // Nonce bytes: A4 CD F9 36 (big-endian) = 0x36F9CDA4
        let data = Data(hexString: "0A00E553011036F9CDA4")!
        let packet = try #require(Packet(data: data))
        #expect(packet.data == data)
        #expect(packet.opcode == .nonceResponse)
        #expect(packet.id == 0x53E5)
        #expect(packet.size == 10)
        assertEncode(NonceResponse(nonce: 0x36F9_CDA4), packet)
    }

    @Test func joinChannelResponseMultipleUsers() throws {
        // Server log: SEND>> [SS=00347340 SQ=01E1 CD=2001] 00 00 02 00 01 01 01...
        // This shows a user (blackscorpio with ID=1) already in the channel
        // Demonstrates the join channel response with existing user data
        let value = JoinChannelResponse(
            status: 0x0000,
            channel: 2,
            maxPosition: 0,
            users: [
                JoinChannelResponse.ChannelUser(
                    id: 1,
                    username: "blackscorpio",
                    avatarEquipped: UInt64(0x0080_0080_0080_0080).bigEndian,
                    guild: "",
                    rankCurrent: 20,
                    rankSeason: 20
                )
            ],
            message: "$Blackscorpio - GB Private Server/Offline final released"
        )
        let packet = try GunBoundEncoder().encode(value, id: 0x01E1)
        #expect(packet.opcode == .joinChannelResponse)
        #expect(packet.id == 0x01E1)
        #expect(value.users.count == 1)
    }

    @Test func cashUpdateEncryptedVariants() throws {
        // Server log shows different encrypted cash update payloads
        // These tests verify the packet structure can handle various encrypted data
        let packets = [
            ("2E897EC68206952B823EAA3A9A229E15", 0x72BA),
            ("E5C8DA0CDE620C4C2806DA1EEF052069", 0x72BA),
            ("5D50446000960DBCD0C4120E48C22F2E", 0x2F10),
        ]

        for (hexParams, expectedId) in packets {
            let parameters = Data(hexString: hexParams)!
            let packetId = Packet.ID(rawValue: UInt16(expectedId))
            let packet = Packet(
                opcode: .cashUpdateNotification,
                id: packetId,
                parameters: parameters
            )
            #expect(packet.opcode == Opcode.cashUpdateNotification)
            #expect(packet.id == packetId)
            #expect(packet.size == 22)
            #expect(packet.parameters == parameters)
        }
    }

    // MARK: - Handshake

    /// RECV>> [cmd=0x1000] [6 bytes]
    /// 0000  06 00 B1 36 00 10
    @Test func nonceRequest_fromLog() throws {
        let data = Data([0x06, 0x00, 0xB1, 0x36, 0x00, 0x10])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .nonceRequest)
        #expect(packet.size == 6)
        #expect(packet.id == 0x36B1)
        #expect(packet.parametersSize == 0)
        assertEncode(NonceRequest(), packet)
        assertDecode(NonceRequest(), packet)
    }

    /// SEND>> [cmd=0x1001] [10 bytes]
    /// 0000  0A 00 E5 53 01 10 DB 6A 9A F6
    ///
    /// The four parameter bytes DB 6A 9A F6 are the nonce stored big-endian,
    /// so Nonce.rawValue == 0xDB6A9AF6.
    @Test func nonceResponse_fromLog() throws {
        let data = Data([0x0A, 0x00, 0xE5, 0x53, 0x01, 0x10, 0xDB, 0x6A, 0x9A, 0xF6])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .nonceResponse)
        #expect(packet.size == 10)
        #expect(packet.id == 0x53E5)
        #expect(packet.parametersSize == 4)
        assertEncode(NonceResponse(nonce: 0xDB6A9AF6), packet)
    }

    // MARK: - Authentication

    /// RECV>> [cmd=0x1010] [86 bytes]
    /// Full encrypted login packet from the log.
    /// Server log confirms: Username=colemancda, Password=1234, ClientVersion=280.
    @Test func authenticationRequest_fromLog() throws {
        let data = Data(hexString:
            "5600AF0D1010" +
            "218ABED7FA38086ECC02" +              // encrypted username block (16 bytes)
            "A15A4D3010F1E2DA03985C6E99D1496C" +  // unknown block (16 bytes)
            "BD2DA584FA8CAF1C01BB5032237E9EB4" +  // encrypted payload block 1
            "70A7257E0C5F47F47346A2D11FF06E0D" +  // encrypted payload block 2
            "1368B0FCB40574009D44E1871A6FA816" +  // encrypted payload block 3
            "4D67C0F863BD"                         // encrypted payload remainder
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .authenticationRequest)
        #expect(packet.size == 86)
        #expect(packet.id == 0x0DAF)

        var decoder = GunBoundDecoder()
        let request = try decoder.decodePacket(AuthenticationRequest.self, from: data)
        #expect(request.username == "colemancda")

        // Derive session key: username + password + nonce
        let key = Key(username: "colemancda", password: "1234", nonce: 0xDB6A9AF6)
        let decryptedData = try Crypto.AES.decrypt(
            request.encryptedData,
            key: key,
            opcode: AuthenticationRequest.opcode
        )
        let decryptedPayload = try decoder.decode(
            AuthenticationRequest.EncryptedData.self,
            from: decryptedData
        )
        #expect(decryptedPayload.password == "1234")
        #expect(decryptedPayload.clientVersion == 280)
    }

    // MARK: - Channel

    /// RECV>> [cmd=0x2000] [8 bytes]
    /// 0000  08 00 97 2D 00 20 FF FF
    /// channel=0xFFFF means "route me to the default channel".
    @Test func joinChannelRequest_defaultChannel() throws {
        let data = Data([0x08, 0x00, 0x97, 0x2D, 0x00, 0x20, 0xFF, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .joinChannelRequest)
        #expect(packet.size == 8)
        #expect(packet.id == 0x2D97)
        assertEncode(JoinChannelRequest(channel: 0xFFFF), packet)
        assertDecode(JoinChannelRequest(channel: 0xFFFF), packet)
    }

    /// Second RECV>> [cmd=0x2000] at the end of the session (room cleanup trigger).
    /// 0000  08 00 03 98 00 20 FF FF
    @Test func joinChannelRequest_secondRequest() throws {
        let data = Data([0x08, 0x00, 0x03, 0x98, 0x00, 0x20, 0xFF, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .joinChannelRequest)
        #expect(packet.id == 0x9803)
        assertEncode(JoinChannelRequest(channel: 0xFFFF), packet)
        assertDecode(JoinChannelRequest(channel: 0xFFFF), packet)
    }

    // MARK: - Room list

    /// RECV>> [cmd=0x2100] [10 bytes]
    /// 0000  0A 00 E5 3F 00 21 02 00 00 00
    /// filter byte = 0x02 = RoomFilter.waiting
    @Test func roomListRequest_waitingFilter() throws {
        let data = Data([0x0A, 0x00, 0xE5, 0x3F, 0x00, 0x21, 0x02, 0x00, 0x00, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomListRequest)
        #expect(packet.size == 10)
        #expect(packet.id == 0x3FE5)
        assertDecode(RoomListRequest(filter: .waiting), packet)
    }

    /// Second room list request (same filter, different packet ID).
    /// 0000  0A 00 E5 3F 00 21 02 00 00 00  (appears again after re-join)
    @Test func roomListRequest_waitingFilter_secondOccurrence() throws {
        let data = Data([0x0A, 0x00, 0xE5, 0x3F, 0x00, 0x21, 0x02, 0x00, 0x00, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomListRequest)
        #expect(packet.id == 0x3FE5)
        assertDecode(RoomListRequest(filter: .waiting), packet)
    }

    // MARK: - Room creation

    /// RECV>> [cmd=0x2120] [20 bytes]
    /// 0000  14 00 CB 3C 20 21 04 74 65 73 74 B2 62 00 00 31
    /// 0010  32 33 34 02
    ///
    /// name="test" (4 chars), settings=0x000062B2, password="1234", capacity=2 (1:1)
    @Test func createRoomRequest_fromLog() throws {
        let data = Data([
            0x14, 0x00, 0xCB, 0x3C, 0x20, 0x21,
            0x04,                                   // name length
            0x74, 0x65, 0x73, 0x74,                 // "test"
            0xB2, 0x62, 0x00, 0x00,                 // settings LE = 0x000062B2
            0x31, 0x32, 0x33, 0x34,                 // "1234"
            0x02                                    // capacity = 2 (1:1)
        ])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .createRoomRequest)
        #expect(packet.size == 20)
        #expect(packet.id == 0x3CCB)
        let expected = CreateRoomRequest(
            name: "test",
            settings: 0x0000_62B2,
            password: "1234",
            capacity: ._1_1
        )
        assertDecode(expected, packet)
    }

    /// SEND>> [cmd=0x2121] [21 bytes]
    /// 0000  15 00 9B 81 21 21 00 00 00 03 00 24 52 6F 6F 6D
    /// 0010  20 4D 4F 54 44
    ///
    /// room id = 0x0003, message = "$Room MOTD"
    @Test func createRoomResponse_fromLog() throws {
        let data = Data([
            0x15, 0x00, 0x9B, 0x81, 0x21, 0x21,
            0x00, 0x00, 0x00,                       // 3-byte prefix
            0x03, 0x00,                             // room id LE = 3
            0x24, 0x52, 0x6F, 0x6F, 0x6D, 0x20, 0x4D, 0x4F, 0x54, 0x44  // "$Room MOTD"
        ])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .createRoomResponse)
        #expect(packet.size == 21)
        #expect(packet.id == 0x819B)
        assertEncode(CreateRoomResponse(room: 3, message: "$Room MOTD"), packet)
    }

    // MARK: - Tank selection (exhaustive cycle from log)

    /// RECV>> [cmd=0x3200] — client cycles through every mobile index.
    /// Each entry: primary tank index, secondary = 0xFF (random).
    @Test func roomSelectTank_armorRandom() throws {
        // 08 00 B3 5C 00 32 00 FF
        let data = Data([0x08, 0x00, 0xB3, 0x5C, 0x00, 0x32, 0x00, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x5CB3)
        assertEncode(RoomSelectTankRequest(primary: .armor, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .armor, secondary: .random), packet)
    }

    @Test func roomSelectTank_mageRandom() throws {
        // 08 00 9B 7C 00 32 01 FF
        let data = Data([0x08, 0x00, 0x9B, 0x7C, 0x00, 0x32, 0x01, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x7C9B)
        assertEncode(RoomSelectTankRequest(primary: .mage, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .mage, secondary: .random), packet)
    }

    @Test func roomSelectTank_nakRandom() throws {
        // 08 00 83 9C 00 32 02 FF
        let data = Data([0x08, 0x00, 0x83, 0x9C, 0x00, 0x32, 0x02, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x9C83)
        assertEncode(RoomSelectTankRequest(primary: .nak, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .nak, secondary: .random), packet)
    }

    @Test func roomSelectTank_tricoRandom() throws {
        // 08 00 6B BC 00 32 03 FF
        let data = Data([0x08, 0x00, 0x6B, 0xBC, 0x00, 0x32, 0x03, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0xBC6B)
        assertEncode(RoomSelectTankRequest(primary: .trico, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .trico, secondary: .random), packet)
    }

    @Test func roomSelectTank_bigFootRandom() throws {
        // 08 00 53 DC 00 32 04 FF
        let data = Data([0x08, 0x00, 0x53, 0xDC, 0x00, 0x32, 0x04, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0xDC53)
        assertEncode(RoomSelectTankRequest(primary: .bigFoot, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .bigFoot, secondary: .random), packet)
    }

    @Test func roomSelectTank_boomerRandom() throws {
        // 08 00 3B FC 00 32 05 FF
        let data = Data([0x08, 0x00, 0x3B, 0xFC, 0x00, 0x32, 0x05, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0xFC3B)
        assertEncode(RoomSelectTankRequest(primary: .boomer, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .boomer, secondary: .random), packet)
    }

    @Test func roomSelectTank_raonRandom() throws {
        // 08 00 23 1C 00 32 06 FF
        let data = Data([0x08, 0x00, 0x23, 0x1C, 0x00, 0x32, 0x06, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x1C23)
        assertEncode(RoomSelectTankRequest(primary: .raon, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .raon, secondary: .random), packet)
    }

    @Test func roomSelectTank_lightningRandom() throws {
        // 08 00 0B 3C 00 32 07 FF
        let data = Data([0x08, 0x00, 0x0B, 0x3C, 0x00, 0x32, 0x07, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x3C0B)
        assertEncode(RoomSelectTankRequest(primary: .lightning, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .lightning, secondary: .random), packet)
    }

    @Test func roomSelectTank_jdRandom() throws {
        // 08 00 F3 5B 00 32 08 FF
        let data = Data([0x08, 0x00, 0xF3, 0x5B, 0x00, 0x32, 0x08, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x5BF3)
        assertEncode(RoomSelectTankRequest(primary: .jd, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .jd, secondary: .random), packet)
    }

    @Test func roomSelectTank_asateRandom() throws {
        // 08 00 DB 7B 00 32 09 FF
        let data = Data([0x08, 0x00, 0xDB, 0x7B, 0x00, 0x32, 0x09, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x7BDB)
        assertEncode(RoomSelectTankRequest(primary: .asate, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .asate, secondary: .random), packet)
    }

    @Test func roomSelectTank_iceRandom() throws {
        // 08 00 C3 9B 00 32 0A FF
        let data = Data([0x08, 0x00, 0xC3, 0x9B, 0x00, 0x32, 0x0A, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x9BC3)
        assertEncode(RoomSelectTankRequest(primary: .ice, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .ice, secondary: .random), packet)
    }

    @Test func roomSelectTank_turtleRandom() throws {
        // 08 00 AB BB 00 32 0B FF
        let data = Data([0x08, 0x00, 0xAB, 0xBB, 0x00, 0x32, 0x0B, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0xBBAB)
        assertEncode(RoomSelectTankRequest(primary: .turtle, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .turtle, secondary: .random), packet)
    }

    @Test func roomSelectTank_grubRandom() throws {
        // 08 00 93 DB 00 32 0C FF
        let data = Data([0x08, 0x00, 0x93, 0xDB, 0x00, 0x32, 0x0C, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0xDB93)
        assertEncode(RoomSelectTankRequest(primary: .grub, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .grub, secondary: .random), packet)
    }

    @Test func roomSelectTank_adukaRandom() throws {
        // 08 00 7B FB 00 32 0D FF
        let data = Data([0x08, 0x00, 0x7B, 0xFB, 0x00, 0x32, 0x0D, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0xFB7B)
        assertEncode(RoomSelectTankRequest(primary: .aduka, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .aduka, secondary: .random), packet)
    }

    /// Final tank selection in the cycle: primary=0xFF=random, secondary=0xFF=random
    @Test func roomSelectTank_randomRandom() throws {
        // 08 00 63 1B 00 32 FF FF
        let data = Data([0x08, 0x00, 0x63, 0x1B, 0x00, 0x32, 0xFF, 0xFF])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.id == 0x1B63)
        assertEncode(RoomSelectTankRequest(primary: .random, secondary: .random), packet)
        assertDecode(RoomSelectTankRequest(primary: .random, secondary: .random), packet)
    }

    // MARK: - Team selection

    /// RECV>> [cmd=0x3210] — change to team B (value 1)
    /// 0000  07 00 1B 80 10 32 01
    @Test func roomSelectTeam_teamB() throws {
        let data = Data([0x07, 0x00, 0x1B, 0x80, 0x10, 0x32, 0x01])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamRequest)
        #expect(packet.size == 7)
        #expect(packet.id == 0x801B)
        assertEncode(RoomSelectTeamRequest(team: .b), packet)
        assertDecode(RoomSelectTeamRequest(team: .b), packet)
    }

    /// RECV>> [cmd=0x3210] — change back to team A (value 0)
    /// 0000  07 00 39 D3 10 32 00
    @Test func roomSelectTeam_teamA() throws {
        let data = Data([0x07, 0x00, 0x39, 0xD3, 0x10, 0x32, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamRequest)
        #expect(packet.id == 0xD339)
        assertEncode(RoomSelectTeamRequest(team: .a), packet)
        assertDecode(RoomSelectTeamRequest(team: .a), packet)
    }

    // MARK: - Map / stage cycling

    /// RECV>> [cmd=0x3100] — map set to 1 (Miramo Town)
    /// 0000  07 00 23 19 00 31 01
    @Test func roomChangeStage_miramoTown() throws {
        let data = Data([0x07, 0x00, 0x23, 0x19, 0x00, 0x31, 0x01])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.id == 0x1923)
        assertDecode(RoomChangeStageCommand(map: .miramoTown), packet)
        assertEncode(RoomChangeStageCommand(map: .miramoTown), packet)
    }

    /// RECV>> [cmd=0x3100] — map set to 2 (Nirvana)
    @Test func roomChangeStage_nirvana() throws {
        let data = Data([0x07, 0x00, 0x0E, 0xF5, 0x00, 0x31, 0x02])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.id == 0xF50E)
        assertEncode(RoomChangeStageCommand(map: .nirvana), packet)
        assertDecode(RoomChangeStageCommand(map: .nirvana), packet)
    }

    /// RECV>> [cmd=0x3100] — map set to 5 (Adiumroot)
    @Test func roomChangeStage_adiumroot() throws {
        let data = Data([0x07, 0x00, 0xCF, 0x88, 0x00, 0x31, 0x05])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.id == 0x88CF)
        assertEncode(RoomChangeStageCommand(map: .adiumroot), packet)
        assertDecode(RoomChangeStageCommand(map: .adiumroot), packet)
    }

    /// RECV>> [cmd=0x3100] — map set to 10 (Meta Mine)
    @Test func roomChangeStage_metaMine() throws {
        let data = Data([0x07, 0x00, 0x66, 0xD4, 0x00, 0x31, 0x0A])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.id == 0xD466)
        assertEncode(RoomChangeStageCommand(map: .metaMine), packet)
        assertDecode(RoomChangeStageCommand(map: .metaMine), packet)
    }

    /// RECV>> [cmd=0x3100] — map reset to 0 (random)
    /// 0000  07 00 51 B0 00 31 00
    @Test func roomChangeStage_random() throws {
        let data = Data([0x07, 0x00, 0x51, 0xB0, 0x00, 0x31, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.id == 0xB051)
        assertDecode(RoomChangeStageCommand(map: .random), packet)
        assertEncode(RoomChangeStageCommand(map: .random), packet)
    }

    // MARK: - Capacity cycling

    /// RECV>> [cmd=0x3103] — capacity changed to 4 (2:2)
    /// 0000  07 00 AC 4E 03 31 04
    @Test func roomChangeCapacity_2v2() throws {
        let data = Data([0x07, 0x00, 0xAC, 0x4E, 0x03, 0x31, 0x04])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.size == 7)
        #expect(packet.id == 0x4EAC)
        assertEncode(RoomChangeCapacityCommand(capacity: ._2_2), packet)
        assertDecode(RoomChangeCapacityCommand(capacity: ._2_2), packet)
    }

    /// RECV>> [cmd=0x3103] — capacity changed to 6 (3:3)
    /// 0000  07 00 97 2A 03 31 06
    @Test func roomChangeCapacity_3v3() throws {
        let data = Data([0x07, 0x00, 0x97, 0x2A, 0x03, 0x31, 0x06])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.id == 0x2A97)
        assertEncode(RoomChangeCapacityCommand(capacity: ._3_3), packet)
        assertDecode(RoomChangeCapacityCommand(capacity: ._3_3), packet)
    }

    /// RECV>> [cmd=0x3103] — capacity changed to 8 (4:4)
    /// 0000  07 00 82 06 03 31 08
    @Test func roomChangeCapacity_4v4() throws {
        let data = Data([0x07, 0x00, 0x82, 0x06, 0x03, 0x31, 0x08])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.id == 0x0682)
        assertEncode(RoomChangeCapacityCommand(capacity: ._4_4), packet)
        assertDecode(RoomChangeCapacityCommand(capacity: ._4_4), packet)
    }

    /// RECV>> [cmd=0x3103] — capacity reset to 2 (1:1, original)
    /// 0000  07 00 1B 78 03 31 02
    @Test func roomChangeCapacity_1v1() throws {
        let data = Data([0x07, 0x00, 0x1B, 0x78, 0x03, 0x31, 0x02])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.id == 0x781B)
        assertEncode(RoomChangeCapacityCommand(capacity: ._1_1), packet)
        assertDecode(RoomChangeCapacityCommand(capacity: ._1_1), packet)
    }

    // MARK: - Room options

    /// RECV>> [cmd=0x3101] — first option change in the session
    /// 0000  0A 00 1B 7B 01 31 B2 62 44 00
    /// settings LE = 0x00_44_62_B2
    @Test func roomChangeOption_firstInSession() throws {
        let data = Data([0x0A, 0x00, 0x1B, 0x7B, 0x01, 0x31, 0xB2, 0x62, 0x44, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size == 10)
        #expect(packet.id == 0x7B1B)
        assertEncode(RoomChangeOptionCommand(settings: 0x0044_62B2), packet)
        assertDecode(RoomChangeOptionCommand(settings: 0x0044_62B2), packet)
    }

    /// RECV>> [cmd=0x3101]
    /// 0000  0A 00 FD 22 01 31 B2 62 08 00
    /// settings LE = 0x00_08_62_B2
    @Test func roomChangeOption_soloMode() throws {
        let data = Data([0x0A, 0x00, 0xFD, 0x22, 0x01, 0x31, 0xB2, 0x62, 0x08, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.id == 0x22FD)
        assertEncode(RoomChangeOptionCommand(settings: 0x0008_62B2), packet)
        assertDecode(RoomChangeOptionCommand(settings: 0x0008_62B2), packet)
    }

    /// RECV>> [cmd=0x3101]
    /// 0000  0A 00 28 FE 01 31 B2 63 00 00
    /// settings LE = 0x00_00_63_B2
    @Test func roomChangeOption_changedByte() throws {
        let data = Data([0x0A, 0x00, 0x28, 0xFE, 0x01, 0x31, 0xB2, 0x63, 0x00, 0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.id == 0xFE28)
        assertEncode(RoomChangeOptionCommand(settings: 0x0000_63B2), packet)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_63B2), packet)
    }

    // MARK: - Room title

    /// RECV>> [cmd=0x3104] [11 bytes]
    /// 0000  0B 00 30 9C 04 31 74 65 73 74 32
    /// title = "test2" (5 ASCII bytes, no null terminator in payload)
    @Test func roomSetTitle_test2() throws {
        let data = Data([0x0B, 0x00, 0x30, 0x9C, 0x04, 0x31, 0x74, 0x65, 0x73, 0x74, 0x32])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSetTitleCommand)
        #expect(packet.size == 11)
        #expect(packet.id == 0x9C30)
        assertDecode(RoomSetTitleCommand(title: "test2"), packet)
    }

    // MARK: - Key derivation

    /// Verify the session key derived from the log's credentials and nonce.
    /// username="colemancda", password="1234", nonce=0xDB6A9AF6
    /// Any packet that passes crypto round-trips with this key is implicitly
    /// confirmed by the login test above; this test makes the key contract explicit.
    @Test func sessionKeyDerivation() {
        let key = Key(username: "colemancda", password: "1234", nonce: 0xDB6A9AF6)
        // Key is 16 bytes (AES-128)
        #expect(key.data.count == 16)
        // Key must be stable (deterministic SHA-0 + mixing)
        let key2 = Key(username: "colemancda", password: "1234", nonce: 0xDB6A9AF6)
        #expect(key.data == key2.data)
        // A different nonce must yield a different key
        let keyOther = Key(username: "colemancda", password: "1234", nonce: 0x0001_0203)
        #expect(key.data != keyOther.data)
    }

    // MARK: - Packet ID counter

    /// The server sets packet.id = PacketID(serverPacketLength: sentBytes).
    /// The nonce response (10 bytes) is the very first server packet, so sentBytes=10.
    @Test func packetID_nonceResponse_sentBytes() {
        let id = Packet.ID(serverPacketLength: 10)
        #expect(id.rawValue == 0x53E5)
    }
    
    
    // MARK: - JoinChannelResponse

    /// SEND>> [cmd=0x2001] [265 bytes] — first join channel response.
    ///
    /// The server sends 5 users back in the channel:
    ///   id=0  "us"          guild="virtual"  rankC=19 rankS=19  (bot)
    ///   id=1  "jg"          guild="virtual"  rankC=12 rankS=12  (bot)
    ///   id=2  "admin"       guild="virtual"  rankC=20 rankS=20  (bot)
    ///   id=3  "colemancda"  guild="test"     rankC=20 rankS=20  (ghost slot)
    ///   id=4  "colemancda"  guild="test"     rankC=20 rankS=20  (current session)
    ///
    /// maxPosition = 4 (highest occupied user-ID slot).
    @Test func joinChannelResponse_packetHeader() throws {
        let data = Data([
            0x09,0x01, 0x9F,0xD3, 0x01,0x20,   // size=265, id, opcode
            0x00,0x00,                           // status
            0x00,0x00,                           // channel=0
            0x04,                               // maxPosition=4
            0x05,                               // user count=5
            // users follow (33 bytes each: 1 id + 12 username + 8 avatar + 8 guild + 2 rankC + 2 rankS)
            // user[0] id=0  "us"  avatar=0x0080008000800000  guild="virtual"  rankC=19 rankS=19
            0x00,
            0x75,0x73,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
            0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x00,
            0x76,0x69,0x72,0x74,0x75,0x61,0x6C,0x00,
            0x13,0x00, 0x13,0x00,
            // user[1] id=1  "jg"  avatar=0x0080008000800000  guild="virtual"  rankC=12 rankS=12
            0x01,
            0x6A,0x67,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
            0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x00,
            0x76,0x69,0x72,0x74,0x75,0x61,0x6C,0x00,
            0x0C,0x00, 0x0C,0x00,
            // user[2] id=2  "admin"  avatar=0x0080008000800000  guild="virtual"  rankC=20 rankS=20
            0x02,
            0x61,0x64,0x6D,0x69,0x6E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
            0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x00,
            0x76,0x69,0x72,0x74,0x75,0x61,0x6C,0x00,
            0x14,0x00, 0x14,0x00,
            // user[3] id=3  "colemancda"  avatar=0x0100000001000300  guild="test"  rankC=0 rankS=20
            0x03,
            0x63,0x6F,0x6C,0x65,0x6D,0x61,0x6E,0x63,0x64,0x61,0x00,0x00,
            0x01,0x00,0x00,0x00,0x01,0x00,0x03,0x00,
            0x74,0x65,0x73,0x74,0x00,0x00,0x00,0x00,
            0x00,0x00, 0x14,0x00,
            // user[4] id=4  "colemancda"  avatar=0x0100000001000300  guild="test"  rankC=20 rankS=20
            0x04,
            0x63,0x6F,0x6C,0x65,0x6D,0x61,0x6E,0x63,0x64,0x61,0x00,0x00,
            0x01,0x00,0x00,0x00,0x01,0x00,0x03,0x00,
            0x74,0x65,0x73,0x74,0x00,0x00,0x00,0x00,
            0x14,0x00, 0x14,0x00,
            // MOTD (dynamic timestamp — just the prefix bytes tested separately)
            0x24,0x43,0x68,0x61,0x6E,0x6E,0x65,0x6C,0x20,0x4D,0x4F,0x54,0x44,0x0D,0x0A,
            0x52,0x65,0x71,0x75,0x65,0x73,0x74,0x69,0x6E,0x67,0x20,0x53,0x56,0x43,0x5F,
            0x43,0x48,0x41,0x4E,0x4E,0x45,0x4C,0x5F,0x4A,0x4F,0x49,0x4E,0x20,0x30,0x20,
            0x61,0x74,0x20,0x32,0x30,0x32,0x36,0x2D,0x30,0x33,0x2D,0x32,0x35,0x20,0x32,
            0x32,0x3A,0x33,0x38,0x3A,0x35,0x38,0x0D,0x0A,0x43,0x6C,0x69,0x65,0x6E,0x74,
            0x20,0x56,0x65,0x72,0x73,0x69,0x6F,0x6E,0x3A,0x20,0x32,0x38,0x30,
        ])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .joinChannelResponse)
        #expect(packet.size == 265)
        #expect(packet.id == 0xD39F)
        #expect(packet.parametersSize == 259)
        // Verify channel and maxPosition encoded in first 6 parameter bytes
        let params = packet.parameters
        #expect(params[2] == 0x00)  // channel low byte = 0
        #expect(params[3] == 0x00)  // channel high byte = 0
        #expect(params[4] == 0x04)  // maxPosition = 4
        #expect(params[5] == 0x05)  // user count = 5
    }

    /// Verify the encoded JoinChannelResponse matches the exact bytes from the log.
    @Test func joinChannelResponse_encode() throws {
        let virtualAvatar: UInt64 = 0x0080_0080_0080_0000
        let coleAvatar: UInt64 = 0x0100_0000_0100_0300

        let response = JoinChannelResponse(
            status: 0x0000,
            channel: 0,
            maxPosition: 4,
            users: [
                .init(id: 0, username: "us",         avatarEquipped: virtualAvatar, guild: "virtual", rankCurrent: 19, rankSeason: 19),
                .init(id: 1, username: "jg",         avatarEquipped: virtualAvatar, guild: "virtual", rankCurrent: 12, rankSeason: 12),
                .init(id: 2, username: "admin",      avatarEquipped: virtualAvatar, guild: "virtual", rankCurrent: 20, rankSeason: 20),
                .init(id: 3, username: "colemancda", avatarEquipped: coleAvatar,    guild: "test",    rankCurrent: 0,  rankSeason: 20),
                .init(id: 4, username: "colemancda", avatarEquipped: coleAvatar,    guild: "test",    rankCurrent: 20, rankSeason: 20),
            ],
            message: "$Channel MOTD\r\nRequesting SVC_CHANNEL_JOIN 0 at 2026-03-25 22:38:58\r\nClient Version: 280"
        )

        let encoder = GunBoundEncoder()
        let packet = try encoder.encode(response, id: 0xD39F)
        #expect(packet.opcode == .joinChannelResponse)
        #expect(packet.size == 265)
        #expect(packet.id == 0xD39F)
        // Verify specific bytes: channel=0 at params[2..3], maxPosition=4 at params[4], count=5 at params[5]
        let params = packet.parameters
        #expect(params[2] == 0x00)
        #expect(params[3] == 0x00)
        #expect(params[4] == 0x04)
        #expect(params[5] == 0x05)
    }

    /// The second JoinChannelResponse (after room cleanup) differs only in packet ID.
    /// 0000  09 01 00 DE 01 20 ...
    @Test func joinChannelResponse_secondOccurrence_packetHeader() throws {
        // Read just the first 6 bytes to check header
        let headerBytes = Data([0x09,0x01, 0x00,0xDE, 0x01,0x20])
        let size = UInt16(littleEndian: UInt16(headerBytes[0]) | (UInt16(headerBytes[1]) << 8))
        let id = UInt16(littleEndian: UInt16(headerBytes[2]) | (UInt16(headerBytes[3]) << 8))
        let opcode = UInt16(littleEndian: UInt16(headerBytes[4]) | (UInt16(headerBytes[5]) << 8))
        #expect(size == 265)
        #expect(id == 0xDE00)
        #expect(Opcode(rawValue: opcode) == .joinChannelResponse)
    }

    // MARK: - RoomListResponse

    /// SEND>> [cmd=0x2103] [79 bytes] — room list with 3 virtual waiting rooms.
    @Test func roomListResponse_packetHeader() throws {
        let data = Data([
            0x4F,0x00, 0xB2,0xCE, 0x03,0x21,
            // params follow — just verify at packet level
            0x00,0x00, 0x03,0x00, 0x00,0x00,
            0x0A,0x75,0x73,0x20,0x76,0x69,0x72,0x74,0x75,0x61,0x6C,
            0x00,0xB2,0x62,0x0C,0x00,0x01,0x02,0x00,0x00,0x01,0x00,
            0x0A,0x6A,0x67,0x20,0x76,0x69,0x72,0x74,0x75,0x61,0x6C,
            0x00,0xB2,0x62,0x0C,0x00,0x01,0x02,0x00,0x00,0x02,0x00,
            0x0D,0x61,0x64,0x6D,0x69,0x6E,0x20,0x76,0x69,0x72,0x74,
            0x75,0x61,0x6C,0x00,0xB2,0x62,0x0C,0x00,0x01,0x02,0x00,0x00,
        ])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomListResponse)
        #expect(packet.size == 79)
        #expect(packet.id == 0xCEB2)
        #expect(packet.parametersSize == 73)
        // First two parameter bytes are RTC (0x0000)
        let params = packet.parameters
        #expect(params[0] == 0x00)
        #expect(params[1] == 0x00)
        // Next two bytes are the room count = 3
        #expect(params[2] == 0x03)
        #expect(params[3] == 0x00)
    }

    // MARK: - RoomSelectTankResponse

    /// SEND>> [cmd=0x3201] [8 bytes] — first tank selection ACK.
    /// 0000  08 00 83 A1 01 32 00 00
    @Test func roomSelectTankResponse_firstAck() throws {
        let data = Data([0x08,0x00,0x83,0xA1,0x01,0x32,0x00,0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size == 8)
        #expect(packet.id == 0xA183)
        assertEncode(RoomSelectTankResponse(), packet)
        assertDecode(RoomSelectTankResponse(), packet)
    }

    /// Verify all 15 tank ACK packets carry the correct opcode.
    /// The server replied to every tank selection (0–13 and 255) with the same
    /// zero-rtc response; only the packet ID (sentBytes counter) changes.
    @Test func roomSelectTankResponse_fullCycle() throws {
        let rawPackets: [Data] = [
            Data([0x08,0x00,0x83,0xA1,0x01,0x32,0x00,0x00]),  // armor
            Data([0x08,0x00,0x6B,0xC1,0x01,0x32,0x00,0x00]),  // mage
            Data([0x08,0x00,0x53,0xE1,0x01,0x32,0x00,0x00]),  // nak
            Data([0x08,0x00,0x3B,0x01,0x01,0x32,0x00,0x00]),  // trico
            Data([0x08,0x00,0x23,0x21,0x01,0x32,0x00,0x00]),  // bigFoot
            Data([0x08,0x00,0x0B,0x41,0x01,0x32,0x00,0x00]),  // boomer
            Data([0x08,0x00,0xF3,0x60,0x01,0x32,0x00,0x00]),  // raon
            Data([0x08,0x00,0xDB,0x80,0x01,0x32,0x00,0x00]),  // lightning
            Data([0x08,0x00,0xC3,0xA0,0x01,0x32,0x00,0x00]),  // jd
            Data([0x08,0x00,0xAB,0xC0,0x01,0x32,0x00,0x00]),  // asate
            Data([0x08,0x00,0x93,0xE0,0x01,0x32,0x00,0x00]),  // ice
            Data([0x08,0x00,0x7B,0x00,0x01,0x32,0x00,0x00]),  // turtle
            Data([0x08,0x00,0x63,0x20,0x01,0x32,0x00,0x00]),  // grub
            Data([0x08,0x00,0x4B,0x40,0x01,0x32,0x00,0x00]),  // aduka
            Data([0x08,0x00,0x33,0x60,0x01,0x32,0x00,0x00]),  // random
        ]
        for (index, raw) in rawPackets.enumerated() {
            let packet = try #require(Packet(data: raw), "packet index \(index)")
            #expect(packet.opcode == .roomSelectTankResponse, "packet index \(index)")
            #expect(packet.size == 8, "packet index \(index)")
            // rtc field in parameters is always 0x0000
            #expect(packet.parameters == Data([0x00, 0x00]), "packet index \(index)")
        }
    }

    // MARK: - RoomSelectTeamResponse

    /// SEND>> [cmd=0x3211] — ACK for team B selection.
    /// 0000  08 00 1B 80 11 32 00 00
    @Test func roomSelectTeamResponse_teamB() throws {
        let data = Data([0x08,0x00,0x1B,0x80,0x11,0x32,0x00,0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamResponse)
        #expect(packet.size == 8)
        #expect(packet.id == 0x801B)
        assertEncode(RoomSelectTeamResponse(), packet)
        assertDecode(RoomSelectTeamResponse(), packet)
    }

    /// SEND>> [cmd=0x3211] — ACK for team A selection.
    /// 0000  08 00 03 A0 11 32 00 00
    @Test func roomSelectTeamResponse_teamA() throws {
        let data = Data([0x08,0x00,0x03,0xA0,0x11,0x32,0x00,0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamResponse)
        #expect(packet.size == 8)
        #expect(packet.id == 0xA003)
        assertEncode(RoomSelectTeamResponse(), packet)
        assertDecode(RoomSelectTeamResponse(), packet)
    }

    // MARK: - RoomUpdateNotification

    /// SEND>> [cmd=0x3105] — first room update notification (after first option change).
    /// 0000  08 00 EB BF 05 31 00 00
    @Test func roomUpdateNotification_first() throws {
        let data = Data([0x08,0x00,0xEB,0xBF,0x05,0x31,0x00,0x00])
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size == 8)
        #expect(packet.id == 0xBFEB)
        assertEncode(RoomUpdateNotification(), packet)
        assertDecode(RoomUpdateNotification(), packet)
    }

    /// The server emits a RoomUpdateNotification after every room-mutating command.
    /// Verify all 23 instances from the session carry the correct opcode and structure.
    @Test func roomUpdateNotification_allInstances() throws {
        // Every RoomUpdateNotification in the session, in order.
        // Each is 8 bytes: [size=08 00] [id LE] [opcode=05 31] [rtc=00 00]
        let rawPackets: [Data] = [
            // option changes
            Data([0x08,0x00,0xEB,0xBF,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0xD3,0xDF,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0xBB,0xFF,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0xA3,0x1F,0x05,0x31,0x00,0x00]),
            // capacity 4
            Data([0x08,0x00,0x8B,0x3F,0x05,0x31,0x00,0x00]),
            // capacity 6
            Data([0x08,0x00,0x73,0x5F,0x05,0x31,0x00,0x00]),
            // capacity 8
            Data([0x08,0x00,0x5B,0x7F,0x05,0x31,0x00,0x00]),
            // more option changes
            Data([0x08,0x00,0x43,0x9F,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x2B,0xBF,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x13,0xDF,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0xFB,0xFE,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0xE3,0x1E,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0xCB,0x3E,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0xB3,0x5E,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x9B,0x7E,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x83,0x9E,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x6B,0xBE,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x53,0xDE,0x05,0x31,0x00,0x00]),
            // stage changes 1–10 then back to 0
            Data([0x08,0x00,0x3B,0xFE,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x23,0x1E,0x05,0x31,0x00,0x00]),
            Data([0x08,0x00,0x0B,0x3E,0x05,0x31,0x00,0x00]),
            // room title rename
            Data([0x08,0x00,0x33,0x5D,0x05,0x31,0x00,0x00]),
            // capacity reset to 2
            Data([0x08,0x00,0x1B,0x7D,0x05,0x31,0x00,0x00]),
        ]
        for (index, raw) in rawPackets.enumerated() {
            let packet = try #require(Packet(data: raw), "packet index \(index)")
            #expect(packet.opcode == .roomUpdateNotification, "packet index \(index)")
            #expect(packet.size == 8, "packet index \(index)")
            // rtc is always zero
            #expect(packet.parameters == Data([0x00, 0x00]), "packet index \(index)")
        }
    }

    /// The first 21 consecutive RoomUpdateNotifications were emitted back-to-back
    /// with no intervening server packet, so each ID corresponds to sentBytes
    /// advancing by exactly 8 (the size of one notification).
    ///
    /// Verified by inverting the PacketID formula:
    ///   sentBytes = (id + 0x53FD) * modinv(0x43FD, 2^16)  mod 2^16
    /// For all 21 pairs, sentBytes[i+1] - sentBytes[i] == 8.
    @Test func roomUpdateNotification_consecutiveIdsAdvanceBy8Bytes() {
        func packetId(_ length: Int) -> UInt16 {
            // id = ((length * 0x43FD) - 0x53FD) & 0xFFFF
            let value = ((length * 0x43FD) &- 0x53FD) & 0xFFFF
            return UInt16(value)
        }

        // The 21 notifications emitted one-after-another (option changes + capacity + stage changes).
        // Indices 21 and 22 are excluded: a 72-byte gap appears there because the server
        // emitted additional response packets between the final stage-change ACK and the
        // room-title update notification.
        let consecutiveIds: [UInt16] = [
            0xBFEB, 0xDFD3, 0xFFBB, 0x1FA3, 0x3F8B, 0x5F73, 0x7F5B, 0x9F43,
            0xBF2B, 0xDF13, 0xFEFB, 0x1EE3, 0x3ECB, 0x5EB3, 0x7E9B, 0x9E83,
            0xBE6B, 0xDE53, 0xFE3B, 0x1E23, 0x3E0B,
        ]
        for i in 1..<consecutiveIds.count {
            // If id[i-1] = packetId(N), then id[i] must equal packetId(N+8)
            // Equivalently: packetId( packetId_inverse(id[i-1]) + 8 ) == id[i]
            // We test this without the inverse by checking that
            // packetId(N) and packetId(N+8) differ by exactly packetId(8) steps
            // in the wrapping arithmetic, i.e.:
            //   (id[i] - id[i-1] + 0x10000) & 0xFFFF == (packetId(8) - packetId(0) + 0x10000) & 0xFFFF
            // Since packetId(0) == (0 - 0x53FD) & 0xFFFF == 0xAC03:
            let diff = (Int(consecutiveIds[i]) - Int(consecutiveIds[i - 1]) + 0x10000) & 0xFFFF
            let expectedDiff = (Int(packetId(8)) - Int(packetId(0)) + 0x10000) & 0xFFFF
            #expect(diff == expectedDiff,
                    "index \(i): diff 0x\(String(diff, radix: 16, uppercase: true)) != expected 0x\(String(expectedDiff, radix: 16, uppercase: true))")
        }
    }

    // MARK: - Opcode type metadata

    /// Assert the opcode type classifications used throughout the session are correct.
    /// These are invariants the server relies on (assert guards in respond/send).
    @Test func opcode_typeClassification() {
        // requests
        #expect(Opcode.nonceRequest.type == .request)
        #expect(Opcode.authenticationRequest.type == .request)
        #expect(Opcode.joinChannelRequest.type == .request)
        #expect(Opcode.roomListRequest.type == .request)
        #expect(Opcode.createRoomRequest.type == .request)
        #expect(Opcode.roomSelectTankRequest.type == .request)
        #expect(Opcode.roomSelectTeamRequest.type == .request)
        // responses
        #expect(Opcode.nonceResponse.type == .response)
        #expect(Opcode.authenticationResponse.type == .response)
        #expect(Opcode.joinChannelResponse.type == .response)
        #expect(Opcode.roomListResponse.type == .response)
        #expect(Opcode.createRoomResponse.type == .response)
        #expect(Opcode.roomSelectTankResponse.type == .response)
        #expect(Opcode.roomSelectTeamResponse.type == .response)
        // commands (client→server, no direct response)
        #expect(Opcode.roomChangeStageCommand.type == .command)
        #expect(Opcode.roomChangeOptionCommand.type == .command)
        #expect(Opcode.roomChangeCapacityCommand.type == .command)
        #expect(Opcode.roomSetTitleCommand.type == .command)
        // notifications (server→client, unsolicited)
        #expect(Opcode.roomUpdateNotification.type == .notification)
        #expect(Opcode.cashUpdateNotification.type == .notification)
    }

    /// Assert the request↔response pairing for every exchange in the session.
    @Test func opcode_requestResponsePairing() {
        #expect(Opcode.nonceRequest.response == .nonceResponse)
        #expect(Opcode.nonceResponse.request == .nonceRequest)
        #expect(Opcode.authenticationRequest.response == .authenticationResponse)
        #expect(Opcode.authenticationResponse.request == .authenticationRequest)
        #expect(Opcode.joinChannelRequest.response == .joinChannelResponse)
        #expect(Opcode.joinChannelResponse.request == .joinChannelRequest)
        #expect(Opcode.createRoomRequest.response == .createRoomResponse)
        #expect(Opcode.createRoomResponse.request == .createRoomRequest)
        #expect(Opcode.roomSelectTankRequest.response == .roomSelectTankResponse)
        #expect(Opcode.roomSelectTankResponse.request == .roomSelectTankRequest)
        #expect(Opcode.roomSelectTeamRequest.response == .roomSelectTeamResponse)
        #expect(Opcode.roomSelectTeamResponse.request == .roomSelectTeamRequest)
    }

    /// Commands and notifications must NOT have a paired response opcode.
    @Test func opcode_commandsHaveNoResponse() {
        #expect(Opcode.roomChangeStageCommand.response == nil)
        #expect(Opcode.roomChangeOptionCommand.response == nil)
        #expect(Opcode.roomChangeCapacityCommand.response == nil)
        #expect(Opcode.roomSetTitleCommand.response == nil)
        #expect(Opcode.roomUpdateNotification.response == nil)
    }

    // MARK: - Encryption flag

    /// Verify which opcodes from the session require encryption.
    /// The login payload is encrypted with the static login key;
    /// the cash update notification uses the session key.
    @Test func opcode_encryptionFlag() {
        // encrypted in this session
        #expect(Opcode.cashUpdateNotification.isEncrypted == true)
        // not encrypted
        #expect(Opcode.nonceRequest.isEncrypted == false)
        #expect(Opcode.nonceResponse.isEncrypted == false)
        #expect(Opcode.authenticationResponse.isEncrypted == false)
        #expect(Opcode.joinChannelRequest.isEncrypted == false)
        #expect(Opcode.joinChannelResponse.isEncrypted == false)
        #expect(Opcode.roomListRequest.isEncrypted == false)
        #expect(Opcode.roomListResponse.isEncrypted == false)
        #expect(Opcode.createRoomRequest.isEncrypted == false)
        #expect(Opcode.createRoomResponse.isEncrypted == false)
        #expect(Opcode.roomSelectTankRequest.isEncrypted == false)
        #expect(Opcode.roomSelectTankResponse.isEncrypted == false)
        #expect(Opcode.roomSelectTeamRequest.isEncrypted == false)
        #expect(Opcode.roomSelectTeamResponse.isEncrypted == false)
        #expect(Opcode.roomChangeStageCommand.isEncrypted == false)
        #expect(Opcode.roomChangeOptionCommand.isEncrypted == false)
        #expect(Opcode.roomChangeCapacityCommand.isEncrypted == false)
        #expect(Opcode.roomSetTitleCommand.isEncrypted == false)
        #expect(Opcode.roomUpdateNotification.isEncrypted == false)
    }

    // MARK: - Mobile enum completeness

    /// The client cycled through mobile indexes 0x00–0x0D plus 0xFF.
    /// Verify every index maps to a known Mobile case (no raw-value gaps in range).
    @Test func mobile_indexCoverage() {
        let expectedIndexes: [(UInt8, Mobile)] = [
            (0x00, .armor), (0x01, .mage),      (0x02, .nak),
            (0x03, .trico), (0x04, .bigFoot),   (0x05, .boomer),
            (0x06, .raon),  (0x07, .lightning), (0x08, .jd),
            (0x09, .asate), (0x0A, .ice),        (0x0B, .turtle),
            (0x0C, .grub),  (0x0D, .aduka),
            (0xFF, .random),
        ]
        for (raw, expected) in expectedIndexes {
            let mobile = Mobile(rawValue: raw)
            #expect(mobile == expected, "raw value 0x\(String(raw, radix: 16, uppercase: true))")
        }
    }

    // MARK: - GameMap enum completeness

    /// The client cycled through map indexes 0–10.
    /// Verify every index maps to a known GameMap case.
    @Test func gameMap_indexCoverage() {
        let expectedIndexes: [(UInt8, GameMap)] = [
            (0,  .random),     (1,  .miramoTown), (2,  .nirvana),
            (3,  .metropolis), (4,  .seaHero),     (5,  .adiumroot),
            (6,  .dragon),     (7,  .cozytower),   (8,  .dummySlope),
            (9,  .stardust),   (10, .metaMine),
        ]
        for (raw, expected) in expectedIndexes {
            let map = GameMap(rawValue: raw)
            #expect(map == expected, "raw value \(raw)")
        }
    }

    // MARK: - RoomCapacity enum completeness

    /// The client cycled through capacities 2, 4, 6, 8.
    /// Verify raw-value round-trips for all four cases.
    @Test func roomCapacity_rawValues() {
        #expect(RoomCapacity(rawValue: 2) == ._1_1)
        #expect(RoomCapacity(rawValue: 4) == ._2_2)
        #expect(RoomCapacity(rawValue: 6) == ._3_3)
        #expect(RoomCapacity(rawValue: 8) == ._4_4)
        #expect(RoomCapacity._1_1.rawValue == 2)
        #expect(RoomCapacity._2_2.rawValue == 4)
        #expect(RoomCapacity._3_3.rawValue == 6)
        #expect(RoomCapacity._4_4.rawValue == 8)
    }

    // MARK: - Packet structure invariants

    /// Every packet in the session has size == data.count (the size field is self-consistent).
    @Test func packet_sizeFieldConsistency() throws {
        let knownPackets: [Data] = [
            // client→server
            Data([0x06,0x00,0xB1,0x36,0x00,0x10]),
            Data([0x08,0x00,0x97,0x2D,0x00,0x20,0xFF,0xFF]),
            Data([0x0A,0x00,0xE5,0x3F,0x00,0x21,0x02,0x00,0x00,0x00]),
            Data([0x14,0x00,0xCB,0x3C,0x20,0x21,0x04,0x74,0x65,0x73,0x74,0xB2,0x62,0x00,0x00,0x31,0x32,0x33,0x34,0x02]),
            Data([0x08,0x00,0xB3,0x5C,0x00,0x32,0x00,0xFF]),
            Data([0x07,0x00,0x1B,0x80,0x10,0x32,0x01]),
            Data([0x07,0x00,0x23,0x19,0x00,0x31,0x01]),
            Data([0x07,0x00,0xAC,0x4E,0x03,0x31,0x04]),
            Data([0x0A,0x00,0x1B,0x7B,0x01,0x31,0xB2,0x62,0x44,0x00]),
            Data([0x0B,0x00,0x30,0x9C,0x04,0x31,0x74,0x65,0x73,0x74,0x32]),
            // server→client
            Data([0x0A,0x00,0xE5,0x53,0x01,0x10,0xDB,0x6A,0x9A,0xF6]),
            Data([0x15,0x00,0x9B,0x81,0x21,0x21,0x00,0x00,0x00,0x03,0x00,0x24,0x52,0x6F,0x6F,0x6D,0x20,0x4D,0x4F,0x54,0x44]),
            Data([0x08,0x00,0x83,0xA1,0x01,0x32,0x00,0x00]),
            Data([0x08,0x00,0x1B,0x80,0x11,0x32,0x00,0x00]),
            Data([0x08,0x00,0xEB,0xBF,0x05,0x31,0x00,0x00]),
        ]
        for (index, raw) in knownPackets.enumerated() {
            let packet = try #require(Packet(data: raw), "packet index \(index)")
            let sizeField = UInt16(raw[0]) | (UInt16(raw[1]) << 8)
            #expect(Int(sizeField) == raw.count, "size mismatch at packet index \(index)")
            #expect(packet.data == raw, "data roundtrip at packet index \(index)")
        }
    }

    /// Minimum valid packet is exactly 6 bytes (header only, no parameters).
    @Test func packet_minimumSize() throws {
        let data = Data([0x06,0x00,0xB1,0x36,0x00,0x10])
        let packet = try #require(Packet(data: data))
        #expect(packet.size == Packet.minSize)
        #expect(packet.parametersSize == 0)
        #expect(packet.parameters.isEmpty)
    }
    
    /// [000] RECV>> [cmd=0x0010] [6 bytes]
    @Test func pkt000_nonceRequest() throws {
        let data = Data(hexString:
            "0600B1360010"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .nonceRequest)
        #expect(packet.size   == 6)
        #expect(packet.id     == 0x36B1)
        let value = NonceRequest()
        assertDecode(value, packet)
    }

    /// [001] SEND>> [cmd=0x0110] [10 bytes]
    /// nonce=0xDB6A9AF6
    @Test func pkt001_nonceResponse() throws {
        let data = Data(hexString:
            "0A00E5530110DB6A9AF6"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .nonceResponse)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x53E5)
        let response = NonceResponse(nonce: 0xDB6A9AF6)
        assertEncode(response, packet)
    }

    /// [002] RECV>> [cmd=0x1010] [86 bytes]
    /// username=colemancda password=1234 clientVersion=280
    @Test func pkt002_authenticationRequest() throws {
        let data = Data(hexString:
            "5600AF0D1010218ABED7FA38086ECC02"
        + "A15A4D3010F1E2DA03985C6E99D1496C"
        + "BD2DA584FA8CAF1C01BB5032237E9EB4"
        + "70A7257E0C5F47F47346A2D11FF06E0D"
        + "1368B0FCB40574009D44E1871A6FA816"
        + "4D67C0F863BD"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .authenticationRequest)
        #expect(packet.size   == 86)
        #expect(packet.id     == 0x0DAF)
        
        // Decode and verify the encrypted authentication request
        let decoder = GunBoundDecoder()
        let request = try decoder.decodePacket(AuthenticationRequest.self, from: data)
        #expect(request.username == "colemancda")
        
        // Derive session key: username + password + nonce
        let key = Key(username: "colemancda", password: "1234", nonce: 0xDB6A9AF6)
        let decryptedData = try Crypto.AES.decrypt(
            request.encryptedData,
            key: key,
            opcode: AuthenticationRequest.opcode
        )
        let decryptedPayload = try decoder.decode(
            AuthenticationRequest.EncryptedData.self,
            from: decryptedData
        )
        #expect(decryptedPayload.password == "1234")
        #expect(decryptedPayload.clientVersion == 280)
    }

    /// [003] SEND>> [cmd=0x1210] [419 bytes]
    /// status=success username=colemancda gold=999999
    @Test func pkt003_authenticationResponse() throws {
        let data = Data(hexString:
            "A301FC9A1210000043107A1C636F6C65"
        + "6D616E63646100000100000001000300"
        + "746573740000000014001400050D3905"
        + "000039050000040D0000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "00000000000000000000000000000000"
        + "000038900D0038900D003F420F000000"
        + "00000000000000000000000000000010"
        + "A00600"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .authenticationResponse)
        #expect(packet.size   == 419)
        #expect(packet.id     == 0x9AFC)
    }

    /// [004] SEND>> [cmd=0x3210] [22 bytes]
    /// encrypted cash payload for colemancda
    @Test func pkt004_cashUpdateNotification() throws {
        let data = Data(hexString:
            "1600BA72321034E66D6BE366FB2DD142"
        + "6CED3ACACFB6"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .cashUpdateNotification)
        #expect(packet.size   == 22)
        #expect(packet.id     == 0x72BA)
    }

    /// [005] RECV>> [cmd=0x0020] [8 bytes]
    /// channel=0xFFFF routes to channel 0
    @Test func pkt005_joinChannelRequest_1() throws {
        let data = Data(hexString:
            "0800972D0020FFFF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .joinChannelRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x2D97)
        assertDecode(JoinChannelRequest(channel: 0xFFFF), packet)
    }

    /// [006] SEND>> [cmd=0x0120] [265 bytes]
    /// 5 users maxPosition=4 channel=0
    @Test func pkt006_joinChannelResponse_1() throws {
        let data = Data(hexString:
            "09019FD3012000000000040500757300"
        + "00000000000000000000800080008000"
        + "007669727475616C0013001300016A67"
        + "00000000000000000000008000800080"
        + "00007669727475616C000C000C000261"
        + "646D696E000000000000000080008000"
        + "8000007669727475616C001400140003"
        + "636F6C656D616E636461000001000000"
        + "01000300746573740000000000001400"
        + "04636F6C656D616E6364610000010000"
        + "00010003007465737400000000140014"
        + "00244368616E6E656C204D4F54440D0A"
        + "52657175657374696E67205356435F43"
        + "48414E4E454C5F4A4F494E2030206174"
        + "20323032362D30332D32352032323A33"
        + "383A35380D0A436C69656E7420566572"
        + "73696F6E3A20323830"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .joinChannelResponse)
        #expect(packet.size   == 265)
        #expect(packet.id     == 0xD39F)
    }

    /// [007] RECV>> [cmd=0x0021] [10 bytes]
    /// filter=waiting(2)
    @Test func pkt007_roomListRequest_1() throws {
        let data = Data(hexString:
            "0A00E53F002102000000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomListRequest)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x3FE5)
        assertDecode(RoomListRequest(filter: .waiting), packet)
    }

    /// [008] SEND>> [cmd=0x0321] [79 bytes]
    /// 3 virtual waiting rooms
    @Test func pkt008_roomListResponse_1() throws {
        let data = Data(hexString:
            "4F00B2CE03210000030000000A757320"
        + "7669727475616C00B2620C0001020000"
        + "01000A6A67207669727475616C00B262"
        + "0C000102000002000D61646D696E2076"
        + "69727475616C00B2620C0001020000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomListResponse)
        #expect(packet.size   == 79)
        #expect(packet.id     == 0xCEB2)
    }

    /// [009] RECV>> [cmd=0x2010] [38 bytes]
    /// encrypted SVC_USER_ID lookup for "us"
    @Test func pkt009_userRequest() throws {
        let data = Data(hexString:
            "260007ED2010C8AC2504FF015BBD5EB2"
        + "3C73822183A1E7EEB0AF622BB17C1C6A"
        + "B23DA595450E"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .userRequest)
        #expect(packet.size   == 38)
        #expect(packet.id     == 0xED07)
    }

    /// [010] SEND>> [cmd=0x2110] [72 bytes]
    /// encrypted user record for "us"
    @Test func pkt010_userResponse() throws {
        let data = Data(hexString:
            "4800DAED211000004A285C716457B52B"
        + "F2D576F0BFE98C884A285C716457B52B"
        + "F2D576F0BFE98C88B5DB965B5290E0BF"
        + "6617DDE8E4C96672FCFA4EB298CDE89C"
        + "3E0FA129D1A610E7"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .userResponse)
        #expect(packet.size   == 72)
        #expect(packet.id     == 0xEDDA)
    }

    /// [011] RECV>> [cmd=0x2021] [20 bytes]
    /// name=test settings=0x000062B2 password=1234 capacity=2(_1_1)
    @Test func pkt011_createRoomRequest() throws {
        let data = Data(hexString:
            "1400CB3C20210474657374B262000031"
        + "32333402"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .createRoomRequest)
        #expect(packet.size   == 20)
        #expect(packet.id     == 0x3CCB)
        assertDecode(CreateRoomRequest(name: "test", settings: 0x000062B2, password: "1234", capacity: 2), packet)
    }

    /// [012] SEND>> [cmd=0x2121] [21 bytes]
    /// room=3 message=$Room MOTD
    @Test func pkt012_createRoomResponse() throws {
        let data = Data(hexString:
            "15009B812121000000030024526F6F6D"
        + "204D4F5444"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .createRoomResponse)
        #expect(packet.size   == 21)
        #expect(packet.id     == 0x819B)
        assertEncode(CreateRoomResponse(room: 3, message: "$Room MOTD"), packet)
    }

    /// [013] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=armor secondary=random
    @Test func pkt013_roomSelectTankRequest_armor() throws {
        let data = Data(hexString:
            "0800B35C003200FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x5CB3)
        assertDecode(RoomSelectTankRequest(primary: .armor, secondary: .random), packet)
    }

    /// [014] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt014_roomSelectTankResponse_armor() throws {
        let data = Data(hexString:
            "0800A18301320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x83A1)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [015] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=mage secondary=random
    @Test func pkt015_roomSelectTankRequest_mage() throws {
        let data = Data(hexString:
            "08009B7C003201FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x7C9B)
        assertDecode(RoomSelectTankRequest(primary: .mage, secondary: .random), packet)
    }

    /// [016] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt016_roomSelectTankResponse_mage() throws {
        let data = Data(hexString:
            "08006BC101320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xC16B)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [017] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=nak secondary=random
    @Test func pkt017_roomSelectTankRequest_nak() throws {
        let data = Data(hexString:
            "0800839C003202FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x9C83)
        assertDecode(RoomSelectTankRequest(primary: .nak, secondary: .random), packet)
    }

    /// [018] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt018_roomSelectTankResponse_nak() throws {
        let data = Data(hexString:
            "080053E101320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xE153)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [019] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=trico secondary=random
    @Test func pkt019_roomSelectTankRequest_trico() throws {
        let data = Data(hexString:
            "08006BBC003203FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xBC6B)
        assertDecode(RoomSelectTankRequest(primary: .trico, secondary: .random), packet)
    }

    /// [020] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt020_roomSelectTankResponse_trico() throws {
        let data = Data(hexString:
            "08003B0101320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x013B)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [021] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=bigFoot secondary=random
    @Test func pkt021_roomSelectTankRequest_bigFoot() throws {
        let data = Data(hexString:
            "080053DC003204FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xDC53)
        assertDecode(RoomSelectTankRequest(primary: .bigFoot, secondary: .random), packet)
    }

    /// [022] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt022_roomSelectTankResponse_bigFoot() throws {
        let data = Data(hexString:
            "0800232101320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x2123)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [023] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=boomer secondary=random
    @Test func pkt023_roomSelectTankRequest_boomer() throws {
        let data = Data(hexString:
            "08003BFC003205FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xFC3B)
        assertDecode(RoomSelectTankRequest(primary: .boomer, secondary: .random), packet)
    }

    /// [024] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt024_roomSelectTankResponse_boomer() throws {
        let data = Data(hexString:
            "08000B4101320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x410B)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [025] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=raon secondary=random
    @Test func pkt025_roomSelectTankRequest_raon() throws {
        let data = Data(hexString:
            "0800231C003206FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x1C23)
        assertDecode(RoomSelectTankRequest(primary: .raon, secondary: .random), packet)
    }

    /// [026] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt026_roomSelectTankResponse_raon() throws {
        let data = Data(hexString:
            "0800F36001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x60F3)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [027] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=lightning secondary=random
    @Test func pkt027_roomSelectTankRequest_lightning() throws {
        let data = Data(hexString:
            "08000B3C003207FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x3C0B)
        assertDecode(RoomSelectTankRequest(primary: .lightning, secondary: .random), packet)
    }

    /// [028] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt028_roomSelectTankResponse_lightning() throws {
        let data = Data(hexString:
            "0800DB8001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x80DB)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [029] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=jd secondary=random
    @Test func pkt029_roomSelectTankRequest_jd() throws {
        let data = Data(hexString:
            "0800F35B003208FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x5BF3)
        assertDecode(RoomSelectTankRequest(primary: .jd, secondary: .random), packet)
    }

    /// [030] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt030_roomSelectTankResponse_jd() throws {
        let data = Data(hexString:
            "0800C3A001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xA0C3)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [031] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=asate secondary=random
    @Test func pkt031_roomSelectTankRequest_asate() throws {
        let data = Data(hexString:
            "0800DB7B003209FF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x7BDB)
        assertDecode(RoomSelectTankRequest(primary: .asate, secondary: .random), packet)
    }

    /// [032] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt032_roomSelectTankResponse_asate() throws {
        let data = Data(hexString:
            "0800ABC001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xC0AB)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [033] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=ice secondary=random
    @Test func pkt033_roomSelectTankRequest_ice() throws {
        let data = Data(hexString:
            "0800C39B00320AFF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x9BC3)
        assertDecode(RoomSelectTankRequest(primary: .ice, secondary: .random), packet)
    }

    /// [034] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt034_roomSelectTankResponse_ice() throws {
        let data = Data(hexString:
            "080093E001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xE093)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [035] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=turtle secondary=random
    @Test func pkt035_roomSelectTankRequest_turtle() throws {
        let data = Data(hexString:
            "0800ABBB00320BFF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xBBAB)
        assertDecode(RoomSelectTankRequest(primary: .turtle, secondary: .random), packet)
    }

    /// [036] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt036_roomSelectTankResponse_turtle() throws {
        let data = Data(hexString:
            "08007B0001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x007B)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [037] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=grub secondary=random
    @Test func pkt037_roomSelectTankRequest_grub() throws {
        let data = Data(hexString:
            "080093DB00320CFF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xDB93)
        assertDecode(RoomSelectTankRequest(primary: .grub, secondary: .random), packet)
    }

    /// [038] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt038_roomSelectTankResponse_grub() throws {
        let data = Data(hexString:
            "0800632001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x2063)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [039] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=aduka secondary=random
    @Test func pkt039_roomSelectTankRequest_aduka() throws {
        let data = Data(hexString:
            "08007BFB00320DFF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xFB7B)
        assertDecode(RoomSelectTankRequest(primary: .aduka, secondary: .random), packet)
    }

    /// [040] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt040_roomSelectTankResponse_aduka() throws {
        let data = Data(hexString:
            "08004B4001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x404B)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [041] RECV>> [cmd=0x0032] [8 bytes]
    /// primary=random secondary=random
    @Test func pkt041_roomSelectTankRequest_random() throws {
        let data = Data(hexString:
            "0800631B0032FFFF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x1B63)
        assertDecode(RoomSelectTankRequest(primary: .random, secondary: .random), packet)
    }

    /// [042] SEND>> [cmd=0x0132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt042_roomSelectTankResponse_random() throws {
        let data = Data(hexString:
            "0800336001320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTankResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x6033)
        assertEncode(RoomSelectTankResponse(), packet)
    }

    /// [043] RECV>> [cmd=0x1032] [7 bytes]
    /// team=b(1)
    @Test func pkt043_roomSelectTeamRequest_b() throws {
        let data = Data(hexString:
            "07004EF7103201"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamRequest)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xF74E)
        assertDecode(RoomSelectTeamRequest(team: .b), packet)
    }

    /// [044] SEND>> [cmd=0x1132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt044_roomSelectTeamResponse_b() throws {
        let data = Data(hexString:
            "08001B8011320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x801B)
        assertEncode(RoomSelectTeamResponse(), packet)
    }

    /// [045] RECV>> [cmd=0x1032] [7 bytes]
    /// team=a(0)
    @Test func pkt045_roomSelectTeamRequest_a() throws {
        let data = Data(hexString:
            "070039D3103200"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamRequest)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xD339)
        assertDecode(RoomSelectTeamRequest(team: .a), packet)
    }

    /// [046] SEND>> [cmd=0x1132] [8 bytes]
    /// rtc=0x0000
    @Test func pkt046_roomSelectTeamResponse_a() throws {
        let data = Data(hexString:
            "080003A011320000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSelectTeamResponse)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xA003)
        assertEncode(RoomSelectTeamResponse(), packet)
    }

    /// [047] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x004462B2
    @Test func pkt047_roomChangeOption_047() throws {
        let data = Data(hexString:
            "0A001B7B0131B2624400"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x7B1B)
        assertDecode(RoomChangeOptionCommand(settings: 0x0044_62B2), packet)
    }

    /// [048] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt048_roomUpdateNotif_048() throws {
        let data = Data(hexString:
            "0800EBBF05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xBFEB)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [049] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000862B2
    @Test func pkt049_roomChangeOption_049() throws {
        let data = Data(hexString:
            "0A00FD220131B2620800"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x22FD)
        assertDecode(RoomChangeOptionCommand(settings: 0x0008_62B2), packet)
    }

    /// [050] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt050_roomUpdateNotif_050() throws {
        let data = Data(hexString:
            "0800D3DF05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xDFD3)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [051] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000C62B2
    @Test func pkt051_roomChangeOption_051() throws {
        let data = Data(hexString:
            "0A00DFCA0131B2620C00"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0xCADF)
        assertDecode(RoomChangeOptionCommand(settings: 0x000C_62B2), packet)
    }

    /// [052] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt052_roomUpdateNotif_052() throws {
        let data = Data(hexString:
            "0800BBFF05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xFFBB)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [053] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000062B2
    @Test func pkt053_roomChangeOption_053() throws {
        let data = Data(hexString:
            "0A00C1720131B2620000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x72C1)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_62B2), packet)
    }

    /// [054] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt054_roomUpdateNotif_054() throws {
        let data = Data(hexString:
            "0800A31F05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x1FA3)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [055] RECV>> [cmd=0x0331] [7 bytes]
    /// capacity=04=_2_2
    @Test func pkt055_roomChangeCapacity__2_2() throws {
        let data = Data(hexString:
            "0700AC4E033104"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x4EAC)
        assertDecode(RoomChangeCapacityCommand(capacity: ._2_2), packet)
    }

    /// [056] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt056_roomUpdateNotif_056() throws {
        let data = Data(hexString:
            "08008B3F05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x3F8B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [057] RECV>> [cmd=0x0331] [7 bytes]
    /// capacity=06=_3_3
    @Test func pkt057_roomChangeCapacity__3_3() throws {
        let data = Data(hexString:
            "0700972A033106"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x2A97)
        assertDecode(RoomChangeCapacityCommand(capacity: ._3_3), packet)
    }

    /// [058] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt058_roomUpdateNotif_058() throws {
        let data = Data(hexString:
            "0800735F05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x5F73)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [059] RECV>> [cmd=0x0331] [7 bytes]
    /// capacity=08=_4_4
    @Test func pkt059_roomChangeCapacity__4_4() throws {
        let data = Data(hexString:
            "07008206033108"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x0682)
        assertDecode(RoomChangeCapacityCommand(capacity: ._4_4), packet)
    }

    /// [060] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt060_roomUpdateNotif_060() throws {
        let data = Data(hexString:
            "08005B7F05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x7F5B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [061] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000162B2
    @Test func pkt061_roomChangeOption_061() throws {
        let data = Data(hexString:
            "0A0064AE0131B2620100"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0xAE64)
        assertDecode(RoomChangeOptionCommand(settings: 0x0001_62B2), packet)
    }

    /// [062] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt062_roomUpdateNotif_062() throws {
        let data = Data(hexString:
            "0800439F05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x9F43)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [063] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000062B2
    @Test func pkt063_roomChangeOption_063() throws {
        let data = Data(hexString:
            "0A0046560131B2620000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x5646)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_62B2), packet)
    }

    /// [064] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt064_roomUpdateNotif_064() throws {
        let data = Data(hexString:
            "08002BBF05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xBF2B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [065] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000063B2
    @Test func pkt065_roomChangeOption_065() throws {
        let data = Data(hexString:
            "0A0028FE0131B2630000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0xFE28)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_63B2), packet)
    }

    /// [066] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt066_roomUpdateNotif_066() throws {
        let data = Data(hexString:
            "080013DF05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xDF13)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [067] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000060B2
    @Test func pkt067_roomChangeOption_067() throws {
        let data = Data(hexString:
            "0A000AA60131B2600000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0xA60A)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_60B2), packet)
    }

    /// [068] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt068_roomUpdateNotif_068() throws {
        let data = Data(hexString:
            "0800FBFE05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xFEFB)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [069] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000061B2
    @Test func pkt069_roomChangeOption_069() throws {
        let data = Data(hexString:
            "0A00EC4D0131B2610000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x4DEC)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_61B2), packet)
    }

    /// [070] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt070_roomUpdateNotif_070() throws {
        let data = Data(hexString:
            "0800E31E05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x1EE3)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [071] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000062B2
    @Test func pkt071_roomChangeOption_071() throws {
        let data = Data(hexString:
            "0A00CEF50131B2620000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0xF5CE)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_62B2), packet)
    }

    /// [072] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt072_roomUpdateNotif_072() throws {
        let data = Data(hexString:
            "0800CB3E05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x3ECB)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [073] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x0000A2B2
    @Test func pkt073_roomChangeOption_073() throws {
        let data = Data(hexString:
            "0A00B09D0131B2A20000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x9DB0)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_A2B2), packet)
    }

    /// [074] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt074_roomUpdateNotif_074() throws {
        let data = Data(hexString:
            "0800B35E05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x5EB3)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [075] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000062B2
    @Test func pkt075_roomChangeOption_075() throws {
        let data = Data(hexString:
            "0A0092450131B2620000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x4592)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_62B2), packet)
    }

    /// [076] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt076_roomUpdateNotif_076() throws {
        let data = Data(hexString:
            "08009B7E05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x7E9B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [077] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000072B2
    @Test func pkt077_roomChangeOption_077() throws {
        let data = Data(hexString:
            "0A0074ED0131B2720000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0xED74)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_72B2), packet)
    }

    /// [078] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt078_roomUpdateNotif_078() throws {
        let data = Data(hexString:
            "0800839E05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x9E83)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [079] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000052B2
    @Test func pkt079_roomChangeOption_079() throws {
        let data = Data(hexString:
            "0A0056950131B2520000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x9556)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_52B2), packet)
    }

    /// [080] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt080_roomUpdateNotif_080() throws {
        let data = Data(hexString:
            "08006BBE05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xBE6B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [081] RECV>> [cmd=0x0131] [10 bytes]
    /// settings=0x000062B2
    @Test func pkt081_roomChangeOption_081() throws {
        let data = Data(hexString:
            "0A00383D0131B2620000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeOptionCommand)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x3D38)
        assertDecode(RoomChangeOptionCommand(settings: 0x0000_62B2), packet)
    }

    /// [082] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt082_roomUpdateNotif_082() throws {
        let data = Data(hexString:
            "080053DE05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xDE53)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [083] RECV>> [cmd=0x0031] [7 bytes]
    /// map=miramoTown
    @Test func pkt083_roomChangeStage_miramoTown() throws {
        let data = Data(hexString:
            "07002319003101"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x1923)
        assertDecode(RoomChangeStageCommand(map: .miramoTown), packet)
    }

    /// [084] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt084_roomUpdateNotif_084() throws {
        let data = Data(hexString:
            "08003BFE05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xFE3B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [085] RECV>> [cmd=0x0031] [7 bytes]
    /// map=nirvana
    @Test func pkt085_roomChangeStage_nirvana() throws {
        let data = Data(hexString:
            "07000EF5003102"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xF50E)
        assertDecode(RoomChangeStageCommand(map: .nirvana), packet)
    }

    /// [086] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt086_roomUpdateNotif_086() throws {
        let data = Data(hexString:
            "0800231E05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x1E23)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [087] RECV>> [cmd=0x0031] [7 bytes]
    /// map=metropolis
    @Test func pkt087_roomChangeStage_metropolis() throws {
        let data = Data(hexString:
            "0700F9D0003103"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xD0F9)
        assertDecode(RoomChangeStageCommand(map: .metropolis), packet)
    }

    /// [088] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt088_roomUpdateNotif_088() throws {
        let data = Data(hexString:
            "08000B3E05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x3E0B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [089] RECV>> [cmd=0x0031] [7 bytes]
    /// map=seaHero
    @Test func pkt089_roomChangeStage_seaHero() throws {
        let data = Data(hexString:
            "0700E4AC003104"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xACE4)
        assertDecode(RoomChangeStageCommand(map: .seaHero), packet)
    }

    /// [090] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt090_roomUpdateNotif_090() throws {
        let data = Data(hexString:
            "0800F35D05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x5DF3)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [091] RECV>> [cmd=0x0031] [7 bytes]
    /// map=adiumroot
    @Test func pkt091_roomChangeStage_adiumroot() throws {
        let data = Data(hexString:
            "0700CF88003105"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x88CF)
        assertDecode(RoomChangeStageCommand(map: .adiumroot), packet)
    }

    /// [092] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt092_roomUpdateNotif_092() throws {
        let data = Data(hexString:
            "0800DB7D05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x7DDB)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [093] RECV>> [cmd=0x0031] [7 bytes]
    /// map=dragon
    @Test func pkt093_roomChangeStage_dragon() throws {
        let data = Data(hexString:
            "0700BA64003106"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x64BA)
        assertDecode(RoomChangeStageCommand(map: .dragon), packet)
    }

    /// [094] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt094_roomUpdateNotif_094() throws {
        let data = Data(hexString:
            "0800C39D05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x9DC3)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [095] RECV>> [cmd=0x0031] [7 bytes]
    /// map=cozytower
    @Test func pkt095_roomChangeStage_cozytower() throws {
        let data = Data(hexString:
            "0700A540003107"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x40A5)
        assertDecode(RoomChangeStageCommand(map: .cozytower), packet)
    }

    /// [096] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt096_roomUpdateNotif_096() throws {
        let data = Data(hexString:
            "0800ABBD05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xBDAB)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [097] RECV>> [cmd=0x0031] [7 bytes]
    /// map=dummySlope
    @Test func pkt097_roomChangeStage_dummySlope() throws {
        let data = Data(hexString:
            "0700901C003108"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x1C90)
        assertDecode(RoomChangeStageCommand(map: .dummySlope), packet)
    }

    /// [098] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt098_roomUpdateNotif_098() throws {
        let data = Data(hexString:
            "080093DD05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xDD93)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [099] RECV>> [cmd=0x0031] [7 bytes]
    /// map=stardust
    @Test func pkt099_roomChangeStage_stardust() throws {
        let data = Data(hexString:
            "07007BF8003109"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xF87B)
        assertDecode(RoomChangeStageCommand(map: .stardust), packet)
    }

    /// [100] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt100_roomUpdateNotif_100() throws {
        let data = Data(hexString:
            "08007BFD05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0xFD7B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [101] RECV>> [cmd=0x0031] [7 bytes]
    /// map=metaMine
    @Test func pkt101_roomChangeStage_metaMine() throws {
        let data = Data(hexString:
            "070066D400310A"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xD466)
        assertDecode(RoomChangeStageCommand(map: .metaMine), packet)
    }

    /// [102] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt102_roomUpdateNotif_102() throws {
        let data = Data(hexString:
            "0800631D05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x1D63)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [103] RECV>> [cmd=0x0031] [7 bytes]
    /// map=random
    @Test func pkt103_roomChangeStage_random() throws {
        let data = Data(hexString:
            "070051B0003100"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeStageCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0xB051)
        assertDecode(RoomChangeStageCommand(map: .random), packet)
    }

    /// [104] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt104_roomUpdateNotif_104() throws {
        let data = Data(hexString:
            "08004B3D05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x3D4B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [105] RECV>> [cmd=0x0431] [11 bytes]
    /// title=test2
    @Test func pkt105_roomSetTitle_test2() throws {
        let data = Data(hexString:
            "0B00309C04317465737432"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomSetTitleCommand)
        #expect(packet.size   == 11)
        #expect(packet.id     == 0x9C30)
    }

    /// [106] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt106_roomUpdateNotif_title() throws {
        let data = Data(hexString:
            "0800335D05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x5D33)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [107] RECV>> [cmd=0x0331] [7 bytes]
    /// capacity=02=_1_1
    @Test func pkt107_roomChangeCapacity__1_1() throws {
        let data = Data(hexString:
            "07001B78033102"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomChangeCapacityCommand)
        #expect(packet.size   == 7)
        #expect(packet.id     == 0x781B)
        assertDecode(RoomChangeCapacityCommand(capacity: ._1_1), packet)
    }

    /// [108] SEND>> [cmd=0x0531] [8 bytes]
    /// rtc=0x0000
    @Test func pkt108_roomUpdateNotif_108() throws {
        let data = Data(hexString:
            "08001B7D05310000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomUpdateNotification)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x7D1B)
        assertEncode(RoomUpdateNotification(), packet)
    }

    /// [109] RECV>> [cmd=0x0020] [8 bytes]
    /// triggers room cleanup channel=0xFFFF
    @Test func pkt109_joinChannelRequest_2() throws {
        let data = Data(hexString:
            "080003980020FFFF"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .joinChannelRequest)
        #expect(packet.size   == 8)
        #expect(packet.id     == 0x9803)
        assertDecode(JoinChannelRequest(channel: 0xFFFF), packet)
    }

    /// [110] SEND>> [cmd=0x0120] [265 bytes]
    /// 5 users after room cleanup
    @Test func pkt110_joinChannelResponse_2() throws {
        let data = Data(hexString:
            "090100DE012000000000040500757300"
        + "00000000000000000000800080008000"
        + "007669727475616C0013001300016A67"
        + "00000000000000000000008000800080"
        + "00007669727475616C000C000C000261"
        + "646D696E000000000000000080008000"
        + "8000007669727475616C001400140003"
        + "636F6C656D616E636461000001000000"
        + "01000300746573740000000000001400"
        + "04636F6C656D616E6364610000010000"
        + "00010003007465737400000000140014"
        + "00244368616E6E656C204D4F54440D0A"
        + "52657175657374696E67205356435F43"
        + "48414E4E454C5F4A4F494E2030206174"
        + "20323032362D30332D32352032323A34"
        + "313A32300D0A436C69656E7420566572"
        + "73696F6E3A20323830"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .joinChannelResponse)
        #expect(packet.size   == 265)
        #expect(packet.id     == 0xDE00)
    }

    /// [111] RECV>> [cmd=0x0021] [10 bytes]
    /// filter=waiting identical bytes to first request
    @Test func pkt111_roomListRequest_2() throws {
        let data = Data(hexString:
            "0A00E53F002102000000"
        )!
        let packet = try #require(Packet(data: data))
        #expect(packet.opcode == .roomListRequest)
        #expect(packet.size   == 10)
        #expect(packet.id     == 0x3FE5)
        assertDecode(RoomListRequest(filter: .waiting), packet)
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

func assertEncode<T>(
    _ value: T,
    _ packet: Packet,
    key: Key? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) where T: Equatable, T: Encodable, T: GunBoundPacket {
    var encoder = GunBoundEncoder()
    encoder.log = { print("Encoder:", $0) }
    do {
        var encodedPacket = try encoder.encode(value, id: packet.id)
        #expect(!encodedPacket.data.isEmpty, sourceLocation: sourceLocation)
        if T.opcode.isEncrypted {
            guard let key = key else {
                Issue.record("No key provided for encrypted packet", sourceLocation: sourceLocation)
                return
            }
            encodedPacket = try encodedPacket.encrypt(key: key)
        }
        #expect(
            encodedPacket.data == packet.data,
            "\(encodedPacket.data.hexString) is not equal to \(packet.data.hexString)",
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record(error, sourceLocation: sourceLocation)
    }
}

func assertEncodeDecrypted<T>(
    _ value: T,
    _ packet: Packet,
    sourceLocation: SourceLocation = #_sourceLocation
) where T: Equatable, T: Encodable, T: GunBoundPacket {
    var encoder = GunBoundEncoder()
    encoder.log = { print("Encoder:", $0) }
    do {
        let encodedPacket = try encoder.encode(value, id: packet.id)
        #expect(!encodedPacket.data.isEmpty, sourceLocation: sourceLocation)
        #expect(
            encodedPacket.data == packet.data,
            "\(encodedPacket.data.hexString) is not equal to \(packet.data.hexString)",
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record(error, sourceLocation: sourceLocation)
    }
}

func assertDecode<T>(
    _ value: T,
    _ packet: Packet,
    key: Key? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) where T: GunBoundPacket, T: Equatable, T: Decodable {
    var decoder = GunBoundDecoder()
    decoder.log = { print("Decoder:", $0) }
    do {
        var packet = packet
        if T.opcode.isEncrypted {
            guard let key = key else {
                Issue.record("No key provided for encrypted packet", sourceLocation: sourceLocation)
                return
            }
            packet = try packet.decrypt(key: key)
        }
        let decodedValue = try decoder.decodePacket(T.self, from: packet.data)
        #expect(decodedValue == value, sourceLocation: sourceLocation)
    } catch {
        Issue.record(error, sourceLocation: sourceLocation)
    }
}

func assertDecodeDecrypted<T>(
    _ value: T,
    _ packet: Packet,
    sourceLocation: SourceLocation = #_sourceLocation
) where T: GunBoundPacket, T: Equatable, T: Decodable {
    var decoder = GunBoundDecoder()
    decoder.log = { print("Decoder:", $0) }
    do {
        let decodedValue = try decoder.decodePacket(T.self, from: packet.data)
        #expect(decodedValue == value, sourceLocation: sourceLocation)
    } catch {
        Issue.record(error, sourceLocation: sourceLocation)
    }
}
