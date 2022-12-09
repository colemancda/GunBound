import Foundation
import Socket
import Algorithms

/// GunBound Classic Server
public final class GunBoundServer <Socket: GunBoundSocket, DataSource: GunBoundServerDataSource> {
    
    // MARK: - Properties
    
    public let configuration: GunBoundServerConfiguration
    
    public let dataSource: DataSource
    
    internal let log: ((String) -> ())?
    
    internal let socket: Socket
    
    private var task: Task<(), Never>?
    
    let storage = Storage()
    
    // MARK: - Initialization
    
    deinit {
        stop()
    }
    
    public init(
        configuration: GunBoundServerConfiguration,
        log: ((String) -> ())? = nil,
        dataSource: DataSource,
        socket: Socket.Type
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
        self.socket = try await Socket.server(address: configuration.address, backlog: configuration.backlog)
        // start running server
        start()
    }
    
    // MARK: - Methods
    
    private func start() {
        assert(task == nil)
        // listening run loop
        self.task = Task.detached(priority: .high) { [weak self] in
            self?.log?("Started GunBound Server")
            do {
                while let socket = self?.socket {
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
                self?.log?("Error waiting for new connection: \(error)")
            }
        }
    }
    
    public func stop() {
        assert(task != nil)
        let storage = self.storage
        self.task?.cancel()
        self.task = nil
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
        
        private let connection: GunBound.Connection<Socket>
        
        private unowned var server: GunBoundServer
        
        private let log: (String) -> ()
        
        var nonce: Nonce = 0x0000
        
        var key: Key?
        
        // MARK: - Initialization
        
        init(
            socket: Socket,
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
            await register { [unowned self] in try await self.login($0) }
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
        private func respond <T> (_ response: T) async where T: GunBoundPacket, T:Encodable {
            log("Response: \(response)")
            guard let _ = await connection.queue(response)
                else { fatalError("Could not add PDU to queue: \(response)") }
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
            self.nonce = Nonce() // refresh random nonce
            return NonceResponse(nonce: nonce)
        }
        
        private func login(_ request: AuthenticationRequest) async throws -> AuthenticationResponse {
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
            let key = Key(
                username: request.username,
                password: password,
                nonce: self.nonce
            )
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
            log("Login attempt for \(request.username) with password \"\(decryptedValue.password)\" client version \(decryptedValue.clientVersion))")
            #endif
            
            guard password == decryptedValue.password else {
                return .badPassword
            }
            
            // store computed key
            self.key = key
            return try AuthenticationResponse(user: user, key: key, encoder: connection.encoder)
        }
    }
}
