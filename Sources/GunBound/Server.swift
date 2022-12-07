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
                        self.log?("[\(newSocket.address)] New connection")
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

internal extension GunBoundServer {
    
    func connection(_ address: GunBoundAddress, didDisconnect error: Swift.Error?) async {
        // remove connection cache
        await storage.removeConnection(address)
        // log
        log?("[\(address.address)]: " + "Did disconnect. \(error?.localizedDescription ?? "")")
    }
}

// MARK: - Supporting Types

///
public protocol GunBoundServerDataSource: AnyObject {
    
    ///
    var serverDirectory: ServerDirectory { get async }
}

public actor InMemoryGunBoundServerDataSource: GunBoundServerDataSource {
    
    public init() { }
    
    ///
    private var state = State()
    
    public func update(_ body: (inout State) -> ()) {
        body(&state)
    }
    
    ///
    public var serverDirectory: ServerDirectory {
        state.serverDirectory
    }
}

public extension InMemoryGunBoundServerDataSource {
    
    struct State: Equatable, Hashable, Codable {
        
        public var serverDirectory: ServerDirectory = []
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
        
        // MARK: - Initialization
        
        init(
            socket: Socket,
            server: GunBoundServer
        ) async {
            let address = socket.address
            let log = server.log
            self.address = address
            self.server = server
            self.connection = await GunBound.Connection(socket: socket, log: { log?("[\(address)] \($0)") }) { error in
                await server.connection(address, didDisconnect: error)
            }
        }
    }
}
