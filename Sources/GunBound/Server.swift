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
}

// MARK: - Supporting Types

///
public protocol GunBoundServerDataSource: AnyObject {
    
    /// get the list of servers
    var serverDirectory: ServerDirectory { get async throws }
    
    /// get the credentials for a user
    func password(for username: String) async throws -> String
    
    /// check user exists
    func userExists(_ username: String) async throws -> Bool
    
    /// User data
    func user(_ username: String) async throws -> User
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
    
    public func password(for username: String) async throws -> String {
        guard let password = state.passwords[username] else {
            throw GunBoundError.unknownUser(username)
        }
        return password
    }
    
    public func userExists(_ username: String) async throws -> Bool {
        state.users[username] != nil
    }
    
    public func user(_ username: String) async throws -> User {
        guard let user = state.users[username] else {
            throw GunBoundError.unknownUser(username)
        }
        return user
    }
}

public extension InMemoryGunBoundServerDataSource {
    
    struct State: Equatable, Hashable, Codable {
        
        public var serverDirectory: ServerDirectory = []
        
        public var users = [String: User]()
        
        public var passwords = [String: String]()
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

internal extension GunBoundServer {
    
    actor Connection {
        
        // MARK: - Properties
        
        let address: GunBoundAddress
        
        private let connection: GunBound.Connection<TCPSocket>
        
        private unowned var server: GunBoundServer
        
        private let log: (String) -> ()
        
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
                await server.storage.removeConnection(address)
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
        private func respond <T> (_ response: T) async where T: GunBoundPacket, T: Encodable {
            log("Response: \(response)")
            assert(T.opcode.type == .response)
            guard let _ = await connection.queue(response)
                else { fatalError("Could not add PDU to queue: \(response)") }
        }
        
        /// Send a server-initiated PDU message.
        private func send <T> (_ notification: T) async where T: GunBoundPacket, T: Encodable  {
            log("Notification: \(notification)")
            assert(T.opcode.type == .notification)
            guard let _ = await connection.queue(notification)
                else { fatalError("Could not add PDU to queue: \(notification)") }
        }
        
        private func close(_ error: Error) async {
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
                    await cashUpdate()
                }
            }
            catch {
                await self.close(error)
            }
        }
        
        private func authenticate(_ request: AuthenticationRequest) async throws -> AuthenticationResponse {
            log("Authentication Request - \(request.username)")
            
            // check if user exists
            guard try await self.server.dataSource.userExists(request.username) else {
                return .badUsername
            }
            
            // get user profile
            let user = try await self.server.dataSource.user(request.username)
            
            // check if banned
            guard user.isBanned == false else {
                return .bannedUser
            }
            
            // decode encrypted data
            let password = try await self.server.dataSource.password(for: request.username)
            let key = await self.connection.authenticate(username: request.username, password: password)
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
                    username: request.username,
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
            // get user profile
            let user: User
            do { user = try await self.server.dataSource.user(username) }
            catch {
                await self.close(error)
                return
            }
            let notification = CashUpdate(cash: user.cash)
            await self.send(notification)
        }
    }
}
