import Foundation

/// GunBound Classic Server
public final class GunBoundServer <TCPSocket: GunBoundSocketTCP, UDPSocket: GunBoundSocketUDP, DataSource: GunBoundServerDataSource> {
    
    // MARK: - Properties
    
    public let configuration: GunBoundServerConfiguration
    
    public let dataSource: DataSource
    
    internal let log: ((String) -> ())?
    
    internal let tcpSocket: TCPSocket
    
    internal let udpSocket: UDPSocket
    
    private var tcpListenTask: Task<(), Never>?
    
    private var udpListenTask: Task<(), Never>?
    
    let storage = Storage()
    
    // MARK: - Initialization
    
    deinit {
        stop()
    }
    
    public init(
        configuration: GunBoundServerConfiguration,
        log: ((String) -> ())? = nil,
        dataSource: DataSource,
        socket: (TCPSocket.Type, UDPSocket.Type)
    ) async throws {
        #if DEBUG
        let log = log ?? {
            NSLog("GunBoundServer: \($0)")
        }
        #endif
        self.configuration = configuration
        self.log = log
        self.dataSource = dataSource
        // create listening socket
        self.tcpSocket = try await TCPSocket.server(
            address: configuration.address,
            backlog: configuration.backlog
        )
        self.udpSocket = try await UDPSocket(address: configuration.address)
        // start running server
        start()
    }
    
    // MARK: - Methods
    
    private func start() {
        assert(tcpListenTask == nil)
        log?("Started GunBound Server")
        // listening run loop
        self.tcpListenTask = Task.detached(priority: .high) { [weak self] in
            do {
                while let socket = self?.tcpSocket {
                    // wait for incoming sockets
                    let newSocket = try await socket.accept()
                    if let self = self {
                        self.log?("[\(newSocket.address.address)] New connection")
                        let connection = await Connection(socket: newSocket, server: self)
                        await self.storage.newConnection(connection)
                        await self.dataSource.didConnect(newSocket.address)
                    }
                }
            }
            catch _ as CancellationError { }
            catch {
                self?.log?("Error waiting for new TCP connection: \(error)")
            }
        }
        self.udpListenTask = Task.detached(priority: .high) { [weak self] in
            do {
                while let socket = self?.udpSocket {
                    // wait for incoming sockets
                    let (recievedData, address) = try await socket.recieve(Packet.maxSize)
                    self?.log?("[\(address.address)] Recieved \(recievedData.count) bytes")
                    try await socket.send(recievedData, to: address)
                    self?.log?("[\(address.address)] Echoed data")
                }
            }
            catch _ as CancellationError { }
            catch {
                self?.log?("Error waiting for new UDP connection: \(error)")
            }
        }
    }
    
    public func stop() {
        assert(tcpListenTask != nil)
        let storage = self.storage
        self.tcpListenTask?.cancel()
        self.tcpListenTask = nil
        self.udpListenTask?.cancel()
        self.udpListenTask = nil
        self.log?("Stopped Server")
        Task {
            await storage.removeAllConnections()
        }
    }
    
    public func send<T>(
        _ packet: T,
        to address: GunBoundAddress
    ) async throws where T: GunBoundPacket, T: Encodable {
        assert(T.opcode.type == .notification)
        guard let connection = await self.storage.connections[address] else {
            throw GunBoundError.disconnected(address)
        }
        await connection.send(packet)
    }
}

// MARK: - Supporting Types

///
public protocol GunBoundServerDataSource: AnyObject {
    
    /// get the list of servers
    var serverDirectory: ServerDirectory { get async throws }
    
    var functionRestrict: FunctionRestrict { get async throws }
    
    func didConnect(_ address: GunBoundAddress) async
    
    func didDisconnect(_ address: GunBoundAddress, username: Username?) async
    
    func position(
        for user: Room.PlayerSession.ID,
        in room: Room.ID,
        map: GameMap
    ) async throws -> (x: UInt, y: UInt)
    
    func register(
        username: Username
    ) async throws -> Bool
    
    /// get the credentials for a user
    func password(
        for username: Username
    ) async throws -> String
    
    /// check user exists
    func userExists(
        for username: Username
    ) async throws -> Bool
    
    /// User data
    func user(
        for username: Username
    ) async throws -> User
    
    func users(
        for usernames: [Username]
    ) async throws -> [User]
    
    func channel(
        for id: Channel.ID
    ) async throws -> Channel
    
    func join(
        channel: Channel.ID,
        for username: Username
    ) async throws -> Channel
    
    func create(
        room name: String,
        in channel: Channel.ID,
        password: RoomPassword,
        settings: UInt32,
        capacity: RoomCapacity,
        username: Username,
        address: GunBoundAddress
    ) async throws -> Room
    
    func join(
        room id: Room.ID,
        username: Username,
        address: GunBoundAddress
    ) async throws -> (Room, Room.PlayerSession)
    
    func rooms(
        in channel: Channel.ID,
        filter: RoomFilter
    ) async throws -> [Room]
    
    func room(
        for id: Room.ID
    ) async throws -> Room
    
    func update<T>(
        room: Room.ID,
        _ body: (inout Room) -> (T)
    ) async throws -> T
}

public actor InMemoryGunBoundServerDataSource: GunBoundServerDataSource {
    
    /// Initializer
    public init(
        stateChanged: ((State) -> ())? = nil
    ) {
        self.stateChanged = stateChanged
    }
    
    ///
    public private(set) var state = State() {
        didSet {
            if let stateChanged = self.stateChanged, state != oldValue {
                stateChanged(state)
            }
        }
    }
    
    internal let stateChanged: ((State) -> ())?
    
    public func update(_ body: (inout State) throws -> ()) rethrows {
        try body(&state)
    }
    
    ///
    public var serverDirectory: ServerDirectory {
        state.serverDirectory
    }
    
    public var functionRestrict: FunctionRestrict {
        state.functionRestrict
    }
    
    public func didConnect(_ address: GunBoundAddress) {
        
    }
    
    public func didDisconnect(_ address: GunBoundAddress, username: Username?) {
        // remove from channels
        for (channelID, channel) in state.channels {
            for (userID, user) in channel.users {
                if user == username {
                    state.channels[channelID]?[userID] = nil
                    break
                }
            }
        }
        // remove from room
        for (roomID, room) in state.rooms {
            for (playerIndex, player) in room.players.enumerated() {
                if player.username == username || player.address == address {
                    state.rooms[roomID]?.players.remove(at: playerIndex)
                    break
                }
            }
            if let isEmpty = state.rooms[roomID]?.players.isEmpty, isEmpty {
                state.rooms[roomID] = nil
            }
        }
    }
    
    public func position(
        for user: Room.PlayerSession.ID,
        in room: Room.ID,
        map: GameMap
    ) throws -> (x: UInt, y: UInt) {
        guard let roomValue = self.state.rooms[room] else {
            throw GunBoundError.unknownRoom(room)
        }
        guard let player = roomValue.players.first(where: { $0.id == user }) else {
            throw GunBoundError.notInRoom
        }
        // get position data for slot
        guard let positionData = self.state.mapData.position(for: user, in: map, team: player.team) else {
            return (0, 0)
        }
        let x = UInt.random(in: positionData.minX ... positionData.maxX)
        let y = positionData.y ?? 0
        return (x, y)
    }
    
    public func register(
        username: Username
    ) throws -> Bool {
        guard state.autoRegister else {
            return false
        }
        guard state.users[username] == nil else {
            return false
        }
        let user = User(id: username)
        self.state.users[username] = user
        self.state.passwords[username.rawValue] = "1234"
        return true
    }
    
    public func password(for username: Username) throws -> String {
        guard let password = state.passwords[username.rawValue] else {
            throw GunBoundError.unknownUser(username.rawValue)
        }
        return password
    }
    
    public func userExists(for username: Username) -> Bool {
        return state.users[username] != nil
    }
    
    public func user(for username: Username) throws -> User {
        guard let user = state.users[username] else {
            throw GunBoundError.unknownUser(username.rawValue)
        }
        return user
    }
    
    public func users(for usernames: [Username]) throws -> [User] {
        return try usernames.map {
            guard let user = state.users[$0] else {
                throw GunBoundError.unknownUser($0.rawValue)
            }
            return user
        }
    }
    
    public func channel(
        for id: Channel.ID
    ) -> Channel {
        let newChannel = Channel(
            id: id,
            users: [:],
            message: "$Welcome to channel \(id.rawValue + 1)\r\nEnjoy!"
        )
        return state.channels[id, default: newChannel]
    }
    
    public func join(
        channel: Channel.ID,
        for username: Username
    ) throws -> Channel {
        let newChannel = Channel(
            id: channel,
            users: [:],
            message: "$Welcome to channel \(channel.rawValue + 1)\r\nEnjoy!"
        )
        // insert user into channel
        let userID: Channel.UserID
        if let id = state.channels[channel, default: newChannel][username] {
            // exisitng user ID
            userID = id
        } else if let id = state.channels[channel, default: newChannel].nextUserID {
            // next user ID
            userID = id
        } else {
            throw GunBoundError.channelFull
        }
        // store user
        state.channels[channel, default: newChannel].users[userID] = username
        // remove from old channels
        let otherChannels = state.channels.keys.lazy.filter { $0 != channel }
        for id in otherChannels {
            if let channel = state.channels[id],
               let userID = channel[username] {
                state.channels[id]?.users[userID] = nil
            }
        }
        // remove from rooms
        for id in state.rooms.keys {
            if let playerIndex = state.rooms[id]?.players.firstIndex(where: { $0.username == username }) {
                state.rooms[id]?.players.remove(at: playerIndex)
            }
            // remove room if empty
            if let players = state.rooms[id]?.players, players.isEmpty {
                state.rooms[id] = nil
            }
        }
        return state.channels[channel, default: newChannel]
    }
    
    public func create(
        room name: String,
        in channel: Channel.ID,
        password: RoomPassword,
        settings: UInt32,
        capacity: RoomCapacity,
        username: Username,
        address: GunBoundAddress
    ) throws -> Room {
        let id = self.state.rooms.values.nextID
        let message = "$Welcome to room \(name)\r\nEnjoy a \(capacity) game!"
        let room = Room(
            id: id,
            channel: channel,
            name: name,
            password: password,
            map: .random,
            settings: settings,
            capacity: capacity,
            isPlaying: false,
            players: [
                // creator
                .init(
                    id: 0x00,
                    username: username,
                    address: address,
                    primaryTank: .random,
                    secondaryTank: .random,
                    team: .a,
                    isReady: false,
                    isAdmin: true
                )
            ],
            message: message
        )
        // store data
        self.state.rooms[id] = room
        // remove user from channels
        for id in state.channels.keys {
            if let channel = state.channels[id],
               let userID = channel[username] {
                state.channels[id]?.users[userID] = nil
            }
        }
        return room
    }
    
    public func join(
        room id: Room.ID,
        username: Username,
        address: GunBoundAddress
    ) throws -> (Room, Room.PlayerSession) {
        guard let room = self.state.rooms[id] else {
            throw GunBoundError.unknownRoom(id)
        }
        guard let playerID = room.nextID else {
            throw GunBoundError.roomFull
        }
        let player = Room.PlayerSession(
            id: playerID,
            username: username,
            address: address,
            primaryTank: .random,
            secondaryTank: .random,
            team: room.nextTeam,
            isReady: false,
            isAdmin: false
        )
        // cache value
        self.state.rooms[id]?.players.append(player)
        return (room, player)
    }
    
    public func room(
        for id: Room.ID
    ) throws -> Room {
        guard let room = state.rooms[id] else {
            throw GunBoundError.unknownRoom(id)
        }
        return room
    }
    
    public func rooms(
        in channel: Channel.ID,
        filter: RoomFilter
    ) -> [Room] {
        return state.rooms.values.filter(filter, in: channel)
    }
    
    public func update<T>(
        room id: Room.ID,
        _ body: (inout Room) -> (T)
    ) throws -> T {
        guard var room = state.rooms[id] else {
            throw GunBoundError.unknownRoom(id)
        }
        let result = body(&room)
        self.state.rooms[id] = room
        return result
    }
}

public extension InMemoryGunBoundServerDataSource {
    
    struct State: Equatable, Hashable, Codable {
        
        public var serverDirectory: ServerDirectory = []
        
        public var functionRestrict: FunctionRestrict = []
        
        public var autoRegister = true
        
        public var users = [Username: User]()
        
        public var passwords = [String: String]()
        
        public var channels = [Channel.ID: Channel]()
        
        public var rooms = [Room.ID: Room]()
        
        public var mapData = MapData.default
    }
}

public struct GunBoundServerConfiguration: Equatable, Hashable, Codable {
    
    public let address: GunBoundAddress
                    
    public let backlog: Int
    
    public init(
        address: GunBoundAddress = .serverDefault,
        backlog: Int = 1000
    ) {
        self.address = address
        self.backlog = backlog
    }
}

internal extension GunBoundServer {
    
    actor Storage {
        
        var connections = [GunBoundAddress: Connection](minimumCapacity: 100)
        
        fileprivate init() { }
        
        func newConnection(_ connection: Connection) {
            connections[connection.address] = connection
        }
        
        func removeConnection(_ address: GunBoundAddress) {
            self.connections[address] = nil
        }
        
        func removeAllConnections() {
            self.connections.removeAll()
        }
    }
}

internal extension GunBoundServer.Connection {
    
    struct ClientState: Equatable, Hashable {
        
        var channel: Channel.ID = 0x00
        
        var room: Room.ID?
    }
}

internal extension GunBoundServer {
    
    actor Connection {
        
        // MARK: - Properties
        
        let address: GunBoundAddress
        
        private let connection: GunBound.Connection<TCPSocket>
        
        private unowned var server: GunBoundServer
        
        private let log: (String) -> ()
        
        var state = ClientState()
        
        // MARK: - Initialization
        
        init(
            socket: TCPSocket,
            server: GunBoundServer
        ) async {
            let address = socket.address
            let serverLog = server.log
            let log: (String) -> () = { serverLog?("[\(address.address)] \($0)") }
            self.log = log
            self.address = address
            self.server = server
            self.connection = await GunBound.Connection(socket: socket, log: log) { error in
                let username = await server.storage.connections[address]?.connection.username
                await server.storage.removeConnection(address)
                await server.dataSource.didDisconnect(address, username: username)
            }
            await self.registerHandlers()
        }
        
        private func registerHandlers() async {
            // server directory
            await register { [unowned self] in try await self.serverDirectory($0) }
            // nonce
            await register { [unowned self] in try await self.nonce($0) }
            // login
            await connection.register { [unowned self] in await self.login($0) }
            // join channel
            await register { [unowned self] in try await self.joinChannel($0) }
            // channel chat
            await connection.register { [unowned self] in await self.channelChat($0) }
            // client command
            await connection.register { [unowned self] in await self.clientCommand($0) }
            // room list
            await register { [unowned self] in try await self.roomList($0) }
            // join room
            await connection.register { [unowned self] in await self.joinRoom($0) }
            // create room
            await register { [unowned self] in try await self.createRoom($0) }
            // select mobile
            await register { [unowned self] in try await self.roomSelectTank($0) }
            // select team
            await register { [unowned self] in try await self.roomSelectTeam($0) }
            // room change stage
            await connection.register { [unowned self] in await self.roomChangeStage($0) }
            // room settings
            await connection.register { [unowned self] in await self.roomChangeOption($0) }
            // room set title
            await connection.register { [unowned self] in await self.roomSetTitle($0) }
            // room change capacity
            await connection.register { [unowned self] in await self.roomChangeCapacity($0) }
            // user ready
            await register { [unowned self] in try await self.userReady($0) }
            // user death (in-game)
            await register { [unowned self] in try await self.userDeath($0) }
            // game result
            await connection.register { [unowned self] in await self.gameResult($0) }
            // start game
            await connection.register { [unowned self] in await self.startGame($0) }
            // return to room after game
            await register { [unowned self] in try await self.roomReturnResult($0) }
        }
        
        @discardableResult
        private func register <Request, Response> (
            _ callback: @escaping (Request) async throws -> (Response)
        ) async -> UInt where Request: GunBoundPacket, Request: Decodable, Response: GunBoundPacket, Response: Encodable {
            await self.connection.register { [unowned self] request in
                do {
                    let response = try await callback(request)
                    await self.respond(response)
                }
                catch {
                    await self.close(error)
                }
            }
        }
        
        /// Respond to a client-initiated PDU message.
        internal func respond <T> (_ response: T) async where T: GunBoundPacket, T: Encodable {
            log("Response: \(response)")
            assert(T.opcode.type == .response)
            guard let _ = await connection.queue(response)
                else { fatalError("Could not add PDU to queue: \(response)") }
        }
        
        /// Send a server-initiated PDU message.
        internal func send <T> (_ notification: T) async where T: GunBoundPacket, T: Encodable  {
            log("Notification: \(notification)")
            assert(T.opcode.type == .notification)
            guard let _ = await connection.queue(notification)
                else { fatalError("Could not add PDU to queue: \(notification)") }
        }
        
        internal func close(_ error: Error) async {
            log("Error: \(error)")
            await self.connection.socket.close()
        }
        
        // MARK: - Requests
        
        private func serverDirectory(_ packet: ServerDirectoryRequest) async throws -> ServerDirectoryResponse {
            log("Server Directory Request")
            let directory = try await self.server.dataSource.serverDirectory
            return ServerDirectoryResponse(directory: directory)
        }
        
        private func nonce(_ packet: NonceRequest) async throws -> NonceResponse {
            log("Nonce Request")
            let nonce = await self.connection.refreshNonce()
            return NonceResponse(nonce: nonce)
        }
        
        private func login(_ request: AuthenticationRequest) async {
            do {
                // response
                let response = try await authenticate(request)
                await self.respond(response)
                // send cash update right after notification
                if response.status == .success {
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await cashUpdate()
                    }
                }
            }
            catch {
                await self.close(error)
            }
        }
        
        private func authenticate(_ request: AuthenticationRequest) async throws -> AuthenticationResponse {
            log("Authentication Request - \(request.username)")
            
            // validate username
            guard let username = Username(rawValue: request.username) else {
                return .badUsername
            }
            
            // create if doesnt exist and autoregister enabled
            if try await server.dataSource.register(username: username) {
                log("Registered User - \(username)")
            }
            
            // check if user exists
            guard try await self.server.dataSource.userExists(for: username) else {
                return .badUsername
            }
            
            // get user profile
            let user = try await self.server.dataSource.user(for: username)
            
            // check if banned
            guard user.isBanned == false else {
                return .bannedUser
            }
            
            // decode encrypted data
            let password = try await self.server.dataSource.password(for: username)
            let key = await self.connection.authenticate(username: username, password: password)
            let decryptedData: Data
            do {
                decryptedData = try Crypto.AES.decrypt(request.encryptedData, key: key, opcode: AuthenticationRequest.opcode)
            }
            catch {
                log("Error: \(error)")
                return .badPassword
            }
            
            let decryptedValue = try connection.decoder.decode(AuthenticationRequest.EncryptedData.self, from: decryptedData)
            
            #if DEBUG
            log("Login attempt for \"\(request.username)\" with password \"\(decryptedValue.password)\" client version \(decryptedValue.clientVersion))")
            #endif
            
            guard password == decryptedValue.password else {
                return .badPassword
            }
            
            let session = await self.connection.session
            
            return AuthenticationResponse(userData:
                AuthenticationResponse.UserData(
                    session: session,
                    username: username,
                    avatarEquipped: user.avatarEquipped,
                    guild: user.guild,
                    rankCurrent: user.rankCurrent,
                    rankSeason: user.rankSeason,
                    guildMemberCount: user.guildMemberCount,
                    rankPositionCurrent: user.rankPositionCurrent,
                    rankPositionSeason: user.rankPositionSeason,
                    guildRank: user.guildRank,
                    gpCurrent: user.gpCurrent,
                    gpSeason: user.gpSeason,
                    gold: user.gold,
                    funcRestrict: [] // TODO: funcRestrict
                )
            )
        }
        
        private func cashUpdate() async {
            // must be authenticated
            guard let username = await self.connection.username else {
                return
            }
            log("Cash Update")
            // get user profile
            let user: User
            do { user = try await self.server.dataSource.user(for: username) }
            catch {
                await self.close(error)
                return
            }
            let notification = CashUpdate(cash: user.cash)
            await self.send(notification)
        }
        
        private func joinChannel(_ request: JoinChannelRequest) async throws -> JoinChannelResponse {
            log("Join Channel Request - \(request.channel)")
            // validate auth
            guard let username = await self.connection.username else {
                throw GunBoundError.notAuthenticated
            }
            // determine channel to join
            var targetChannel = request.channel
            if targetChannel == 0xFFFF {
                targetChannel = 0
            }
            // get users in channel
            let channel = try await self.server.dataSource.join(
                channel: targetChannel,
                for: username
            )
            // cache current channel
            self.state.channel = targetChannel
            self.state.room = nil // exit room
            // get users
            let usersByID = channel.users
                .sorted(by: { $0.value < $1.value })
                .map { (id: $0.key, username: $0.value) }// sort users
            let usernames = usersByID.map { $0.username }
            // map values
            let users = try await self.server.dataSource.users(for: usernames).enumerated().map { (index, user) in
                return JoinChannelResponse.ChannelUser(
                    id: usersByID[index].id,
                    username: user.id,
                    avatarEquipped: user.avatarEquipped,
                    guild: user.guild,
                    rankCurrent: user.rankCurrent,
                    rankSeason: user.rankSeason
                )
            }
            // send notifications
            if let user = users.first(where: { $0.username == username }) {
                let notification = JoinChannelNotification(
                    channelPosition: user.id,
                    username: user.username,
                    avatarEquipped: user.avatarEquipped,
                    guild: user.guild,
                    rankCurrent: user.rankCurrent,
                    rankSeason: user.rankSeason
                )
                Task {
                    // send notifications to all clients in channel
                    for (address, connection) in await self.server.storage.connections {
                        // everyone in channel except self
                        guard await connection.state.channel == targetChannel, address != self.address else {
                            continue
                        }
                        await connection.send(notification)
                    }
                }
            }
            let maxPosition = channel.maxUserID ?? 0
            // response
            return JoinChannelResponse(
                status: 0x00, // hardcoded
                channel: targetChannel,
                maxPosition: maxPosition,
                users: users,
                message: channel.message
            )
        }
        
        private func channelChat(_ command: ChannelChatCommand) async {
            log("Channel Chat - \(command.message)")
            do {
                // validate auth
                guard let username = await self.connection.username else {
                    throw GunBoundError.notAuthenticated
                }
                // get users in channel
                let channel = try await self.server.dataSource.channel(for: self.state.channel)
                assert(channel.id == self.state.channel)
                // get user id
                guard let userID = channel[username] else {
                    throw GunBoundError.unknownUser(username.rawValue)
                }
                // notification
                let notification = ChannelChatBroadcast(
                    position: userID,
                    username: username,
                    message: command.message
                )
                // broadcast message to everyone in channel
                for connection in await self.server.storage.connections.values {
                    guard await connection.state.channel == channel.id, await connection.connection.username != nil else {
                        continue
                    }
                    await connection.send(notification)
                }
            }
            catch {
                await close(error)
            }
        }
        
        private func clientCommand(_ command: ClientGenericCommand) async {
            log("Client Command - \(command.command)")
            
        }
        
        private func roomList(_ request: RoomListRequest) async throws -> RoomListResponse {
            log("Room List - Filter \(request.filter)")
            // current channel
            let channel = self.state.channel
            // fetch rooms
            let rooms = try await self.server.dataSource.rooms(in: channel, filter: request.filter).map {
                RoomListResponse.Room(
                    id: $0.id,
                    name: $0.name,
                    map: $0.map,
                    settings: $0.settings,
                    playerCount: numericCast($0.players.count),
                    capacity: $0.capacity,
                    isPlaying: $0.isPlaying,
                    isLocked: $0.isLocked
                )
            }
            return RoomListResponse(rooms: rooms)
        }
        
        private func createRoom(_ request: CreateRoomRequest) async throws -> CreateRoomResponse {
            log("Create Room - \(request.name)")
            // validate auth
            guard let username = await self.connection.username else {
                throw GunBoundError.notAuthenticated
            }
            // current channel
            let channel = self.state.channel
            // insert room
            let room = try await self.server.dataSource.create(
                room: request.name,
                in: channel,
                password: request.password,
                settings: request.settings,
                capacity: request.capacity,
                username: username,
                address: self.address
            )
            // cache current room
            self.state.room = room.id
            // return new room ID and motd
            return CreateRoomResponse(
                room: room.id,
                message: room.message
            )
        }
        
        private func joinRoom(_ request: JoinRoomRequest) async {
            log("Join Room - \(request.room)")
            do {
                // validate auth
                guard let username = await self.connection.username else {
                    throw GunBoundError.notAuthenticated
                }
                // get room password
                let password = try await self.server.dataSource.room(for: request.room).password
                // validate password
                guard password == request.password else {
                    // TODO: Return error response
                    throw GunBoundError.invalidPassword
                }
                // send notification
                Task {
                    let selfNotification = JoinRoomNotificationSelf()
                    await send(selfNotification)
                }
                // new player session in room
                let (room, player) = try await self.server.dataSource.join(
                    room: request.room,
                    username: username,
                    address: address
                )
                // fetch room and players
                let usernames = room.players.map { $0.username }
                let users = try await self.server.dataSource.users(for: usernames)
                let players = room.players
                    .lazy
                    .enumerated()
                    .map { ($1, users[$0]) }
                    .map { (player, user) in
                    JoinRoomResponse.PlayerSession(
                        id: player.id,
                        username: player.username,
                        address: GunBoundAddress(ipAddress: player.address.ipAddress, port: 8363),
                        address2: GunBoundAddress(ipAddress: player.address.ipAddress, port: 8363),
                        primaryTank: player.primaryTank,
                        secondary: player.primaryTank,
                        team: player.team,
                        value0: 0x01,
                        avatarEquipped: user.avatarEquipped,
                        guild: user.guild,
                        rankCurrent: user.rankCurrent,
                        rankSeason: user.rankSeason
                    )
                }
                let response = JoinRoomResponse(
                    rtc: 0x0000,
                    value0: 0x0100,
                    room: room.id,
                    name: room.name,
                    map: room.map,
                    settings: room.settings,
                    value1: 0xFFFFFFFFFFFFFFFF,
                    capacity: room.capacity,
                    players: players,
                    message: room.message
                )
                // cache current room
                self.state.room = room.id
                // wait for notification to send
                Task {
                    try await Task.sleep(for: .seconds(1))
                    await respond(response)
                }
                
                // inform other users
                let otherPlayers = room.players.filter { $0.username != username }
                let user = try await self.server.dataSource.user(for: username)
                let notification = JoinRoomNotification(
                    id: player.id,
                    username: player.username,
                    address: GunBoundAddress(ipAddress: address.ipAddress, port: 8363),
                    address2: GunBoundAddress(ipAddress: address.ipAddress, port: 8363),
                    primaryTank: player.primaryTank,
                    secondary: player.primaryTank,
                    team: player.team,
                    avatarEquipped: user.avatarEquipped,
                    guild: user.guild,
                    rankCurrent: user.rankCurrent,
                    rankSeason: user.rankSeason
                )
                
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    for player in otherPlayers {
                        // send notification
                        await self.server.storage.connections[player.address]?.send(notification)
                    }
                }
            }
            catch {
                await close(error)
            }
        }
        
        private func updateRoom() async {
            log("Room Update")
            let notification = RoomUpdateNotification()
            await send(notification)
        }
        
        private func cleanupRooms() async {
            
        }
        
        private func roomSelectTank(_ request: RoomSelectTankRequest) async throws -> RoomSelectTankResponse {
            log("Select Room Mobile - 1.\(request.primary) 2.\(request.secondary)")
            // get current room
            guard let id = self.state.room,
                let username = await self.connection.username else {
                return RoomSelectTankResponse()
            }
            // update player session state
            try await self.server.dataSource.update(room: id) { room in
                assert(room.id == id)
                guard let index = room.players.firstIndex(where: { player in
                    player.username == username
                }) else { return }
                room.players[index].primaryTank = request.primary
                room.players[index].secondaryTank = request.secondary
            }
            // inform other users
            return RoomSelectTankResponse()
        }
        
        private func roomSelectTeam(_ request: RoomSelectTeamRequest) async throws -> RoomSelectTeamResponse {
            log("Select Room Team - \(request.team)")
            // get current room
            guard let id = self.state.room,
                let username = await self.connection.username else {
                return RoomSelectTeamResponse()
            }
            // update player session state
            try await self.server.dataSource.update(room: id) { room in
                assert(room.id == id)
                guard let index = room.players.firstIndex(where: { player in
                    player.username == username
                }) else { return }
                room.players[index].team = request.team
            }
            return RoomSelectTeamResponse()
        }
        
        private func roomChangeStage(_ command: RoomChangeStageCommand) async {
            log("Change Room Stage - \(command.map)")
            // get current room
            guard let id = self.state.room else {
                return
            }
            // update player session state
            do {
                try await self.server.dataSource.update(room: id) { room in
                    assert(room.id == id)
                    room.map = command.map
                }
            }
            catch {
                await close(error)
                return
            }
            await updateRoom()
        }
        
        private func roomChangeOption(_ command: RoomChangeOptionCommand) async {
            log("Change Room Options - \(command.settings.toHexadecimal())")
            // get current room
            guard let id = self.state.room else {
                return
            }
            // update player session state
            do {
                try await self.server.dataSource.update(room: id) { room in
                    assert(room.id == id)
                    room.settings = command.settings
                }
            }
            catch {
                await close(error)
                return
            }
            await updateRoom()
        }
        
        private func roomChangeCapacity(_ command: RoomChangeCapacityCommand) async {
            log("Change Room Capacity - \(command.capacity)")
            // get current room
            guard let id = self.state.room else {
                return
            }
            // update player session state
            do {
                try await self.server.dataSource.update(room: id) { room in
                    assert(room.id == id)
                    room.capacity = command.capacity
                }
            }
            catch {
                await close(error)
                return
            }
            await updateRoom()
        }
        
        private func roomSetTitle(_ command: RoomSetTitleCommand) async {
            log("Set Room Title - \(command.title)")
            // get current room
            guard let id = self.state.room else {
                return
            }
            // update player session state
            do {
                try await self.server.dataSource.update(room: id) { room in
                    assert(room.id == id)
                    room.name = command.title
                }
            }
            catch {
                await close(error)
                return
            }
            await updateRoom()
        }
        
        private func userReady(_ request: UserReadyRequest) async throws -> UserReadyResponse {
            log("User Ready - \(request.isReady)")
            // get current room
            guard let id = self.state.room,
                let username = await self.connection.username else {
                return UserReadyResponse()
            }
            // update player session state
            try await self.server.dataSource.update(room: id) { room in
                assert(room.id == id)
                guard let index = room.players.firstIndex(where: { player in
                    player.username == username
                }) else { return }
                room.players[index].isReady = request.isReady
            }
            return UserReadyResponse()
        }
        
        private func userDeath(_ request: UserDeathRequest) async throws -> UserDeathResponse {
            log("Player Death")
            // player death side effects
            return UserDeathResponse()
        }
        
        private func gameResult(_ command: GameResultCommand) async {
            log("Game Result")
            do {
                guard let id = self.state.room else {
                    throw GunBoundError.notInRoom
                }
                // mark game as playing
                let players = try await self.server.dataSource.update(room: id) { room in
                    // update state
                    room.isPlaying = false
                    return room.players
                }
                // send notifications
                let notification = GameResultNotification()
                for player in players {
                    guard let connection = await self.server.storage.connections[player.address] else {
                        continue
                    }
                    await connection.send(notification)
                }
            }
            catch {
                await close(error)
            }
        }
        
        private func startGame(_ command: StartGameCommand) async {
            log("Start Game")
            do {
                guard let id = self.state.room else {
                    throw GunBoundError.notInRoom
                }
                // mark game as playing
                let room = try await self.server.dataSource.update(room: id) { room in
                    // update state
                    room.isPlaying = true
                    return room
                }
                // update random stage and tank
                let map = (room.map == .random) ? (GameMap.allCases.randomElement() ?? .random) : room.map
                let playerIDs = room.players.map { $0.id }
                let playerTurnOrder = playerIDs.shuffled()
                // send notifications
                var players = [StartGameNotification.Player]()
                players.reserveCapacity(room.players.count)
                for player in room.players {
                    let primaryTank = (player.primaryTank == .random) ? Mobile.random : player.primaryTank
                    let secondaryTank = (player.secondaryTank == .random) ? Mobile.random : player.secondaryTank
                    let turnOrder = playerTurnOrder.firstIndex(of: player.id)!
                    let position = try await self.server.dataSource.position(for: player.id, in: id, map: map)
                    let notificationPlayer = StartGameNotification.Player(
                        id: player.id,
                        username: player.username,
                        team: player.team,
                        primaryTank: primaryTank,
                        secondaryTank: secondaryTank,
                        xPosition: numericCast(position.x),
                        yPosition: numericCast(position.y),
                        turnOrder: UInt16(turnOrder)
                    )
                    players.append(notificationPlayer)
                }
                assert(players.count == room.players.count)
                let notification = StartGameNotification(
                    map: map,
                    players: players,
                    events: 0xFF00,
                    commandData: command.value0
                )
                for player in room.players {
                    guard let connection = await self.server.storage.connections[player.address] else {
                        continue
                    }
                    await connection.send(notification)
                }
            }
            catch {
                await close(error)
            }
        }
        
        private func roomReturnResult(_ request: RoomReturnResultRequest) async throws -> RoomReturnResultResponse {
            log("Room Return Result")
            return RoomReturnResultResponse()
        }
    }
}
