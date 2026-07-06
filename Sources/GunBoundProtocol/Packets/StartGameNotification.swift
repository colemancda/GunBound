/// Start Game Notification
public struct StartGameNotification: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .startGameNotification }

    public let map: GameMap

    public let players: [Player]

    public let events: UInt16  // 0x00FF FuncRestrict?

    public let commandData: UInt32  // echo the stuff sent by game host

    public init(
        map: GameMap,
        players: [Player],
        events: UInt16,
        commandData: UInt32
    ) {
        self.map = map
        self.players = players
        self.events = events
        self.commandData = commandData
    }
}

extension StartGameNotification: GunBoundPacketDecodable {

    public init(parsing input: inout ParserSpan) throws {
        self.map = try GameMap(parsing: &input)
        let playersCount = try UInt16(parsingLittleEndian: &input)
        var players = [Player]()
        players.reserveCapacity(Int(playersCount))
        for _ in 0..<playersCount {
            players.append(try Player(parsing: &input))
        }
        self.players = players
        self.events = try UInt16(parsingLittleEndian: &input)
        self.commandData = try UInt32(parsingLittleEndian: &input)
    }
}

extension StartGameNotification {

    public func encode(to output: inout ByteWriter) {
        map.encode(to: &output)
        output.write(UInt16(players.count), endianness: .little)
        for player in players {
            player.encode(to: &output)
        }
        output.write(events, endianness: .little)
        output.write(commandData, endianness: .little)
    }
}

// MARK: - Supporting Types

public extension StartGameNotification {

    struct Player: Equatable, Hashable, Identifiable, Sendable {

        public let id: UInt8

        public let username: Username

        public let team: Team

        public let primaryTank: Mobile

        public let secondaryTank: Mobile

        public let xPosition: UInt16

        public let yPosition: UInt16

        public let turnOrder: UInt16

        public init(
            id: UInt8,
            username: Username,
            team: Team,
            primaryTank: Mobile,
            secondaryTank: Mobile,
            xPosition: UInt16,
            yPosition: UInt16,
            turnOrder: UInt16
        ) {
            self.id = id
            self.username = username
            self.team = team
            self.primaryTank = primaryTank
            self.secondaryTank = secondaryTank
            self.xPosition = xPosition
            self.yPosition = yPosition
            self.turnOrder = turnOrder
        }
    }
}

extension StartGameNotification.Player {

    public init(parsing input: inout ParserSpan) throws {
        self.id = try UInt8(parsing: &input)
        self.username = try Username(parsing: &input)
        self.team = try Team(parsing: &input)
        self.primaryTank = try Mobile(parsing: &input)
        self.secondaryTank = try Mobile(parsing: &input)
        self.xPosition = try UInt16(parsingLittleEndian: &input)
        self.yPosition = try UInt16(parsingLittleEndian: &input)
        self.turnOrder = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(id)
        username.encode(to: &output)
        team.encode(to: &output)
        primaryTank.encode(to: &output)
        secondaryTank.encode(to: &output)
        output.write(xPosition, endianness: .little)
        output.write(yPosition, endianness: .little)
        output.write(turnOrder, endianness: .little)
    }
}
