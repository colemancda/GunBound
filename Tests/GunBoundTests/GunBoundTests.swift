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
