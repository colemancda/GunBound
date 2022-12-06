import Foundation
import Socket
import Algorithms

/// GunBound Classic Server
public final class GunBoundServer {
    
    // MARK: - Properties
    
    public let configuration: Configuration
    
    internal let response: (IPv4SocketAddress, Packet) async -> (Packet)
    
    internal let log: ((String) -> ())?
    
    internal let socket: Socket
    
    private var task: Task<(), Never>?
    
    let storage = Storage()
    
    // MARK: - Initialization
    
    deinit {
        stop()
    }
    
    public init(
        configuration: Configuration,
        log: ((String) -> ())? = nil,
        response: @escaping (IPv4SocketAddress, Packet) async -> (Packet)
    ) async throws {
        #if DEBUG
        let log = log ?? {
            NSLog("GunBoundServer: \($0)")
        }
        #endif
        self.configuration = configuration
        self.log = log
        self.response = response
        // create listening socket
        self.socket = try await Socket(.tcp, bind: IPv4SocketAddress(address: configuration.address, port: configuration.port))
        try socket.fileDescriptor.listen(backlog: configuration.backlog)
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
                    let newSocket = try await Socket(fileDescriptor: socket.fileDescriptor.accept())
                    // read remote address
                    let address = try newSocket.fileDescriptor.peerAddress(IPv4SocketAddress.self)
                    if let self = self {
                        self.log?("[\(address.address)] New connection")
                        let connection = await Connection(address: address, socket: newSocket, server: self)
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
        let socket = self.socket
        let storage = self.storage
        self.task?.cancel()
        self.task = nil
        self.log?("Stopped Server")
        Task {
            await storage.removeAllConnections()
            await socket.close()
        }
    }
}

internal extension GunBoundServer {
    
    func connection(_ address: IPv4SocketAddress, didDisconnect error: Swift.Error?) async {
        // remove connection cache
        await storage.removeConnection(address)
        // log
        log?("[\(address.address)]: " + "Did disconnect. \(error?.localizedDescription ?? "")")
    }
}

// MARK: - Supporting Types

public extension GunBoundServer {
    
    struct Configuration: Equatable, Hashable, Codable {
        
        public let address: IPv4Address
        
        public let port: UInt16
                
        public let backlog: Int
        
        public init(
            address: IPv4Address = .any,
            port: UInt16 = 8370,
            backlog: Int = 10_000
        ) {
            self.address = address
            self.port = port
            self.backlog = backlog
        }
    }
}

internal extension GunBoundServer {
    
    actor Storage {
        
        var connections = [IPv4SocketAddress: Connection](minimumCapacity: 100)
        
        fileprivate init() { }
        
        func newConnection(_ connection: Connection) {
            connections[connection.address] = connection
        }
        
        func removeConnection(_ address: IPv4SocketAddress) {
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
        
        let address: IPv4SocketAddress
        
        let socket: Socket
        
        private unowned var server: GunBoundServer
        
        let configuration: Configuration
        
        private(set) var isConnected = true
        
        private(set) var sentBytes = 0
        
        private(set) var recievedBytes = 0
        
        // MARK: - Initialization
        
        deinit {
            let socket = self.socket
            Task { await socket.close() }
        }
        
        init(
            address: IPv4SocketAddress,
            socket: Socket,
            server: GunBoundServer
        ) async {
            self.address = address
            self.socket = socket
            self.server = server
            self.configuration = server.configuration
            await run()
        }
        
        private func run() {
            // start reading
            Task {
                await run()
            }
            Task.detached(priority: .high) { [weak self] in
                guard let stream = self?.socket.event else { return }
                for await event in stream {
                    await self?.socketEvent(event)
                }
                // socket closed
            }
        }
        
        private func socketEvent(_ event: Socket.Event) async {
            switch event {
            case .pendingRead:
                break
            case .read:
                break
            case .write:
                break
            case let .close(error):
                isConnected = false
                await server.connection(address, didDisconnect: error)
            }
        }
        
        private func run() async {
            do {
                // read packet
                let request = try await read()
                self.server.log?("[\(address.address)] Recieved packet \(request.command) ID \(request.id)")
                // respond
                let response = await self.server.response(address, request)
                try await respond(response)
            } catch {
                self.server.log?("[\(address.address)] Error: \(error.localizedDescription)")
                await self.socket.close()
            }
        }
        
        private func read() async throws -> Packet {
            let data = try await socket.read(Packet.maxSize)
            self.server.log?("[\(address.address)] Read \(data.count) bytes")
            guard let packet = Packet(data: data) else {
                throw GunBoundError.invalidData(data)
            }
            self.recievedBytes += data.count
            return packet
        }
        
        private func write(_ data: Data) async throws {
            let chunkSize = Packet.maxSize
            let chunks = data.chunks(ofCount: chunkSize)
            for chunk in chunks {
                try await socket.write(chunk)
            }
            self.sentBytes += data.count
            self.server.log?("[\(address.address)] Wrote \(data.count) bytes (\(chunks.count) chunks)")
        }
        
        private func respond(_ response: Packet) async throws {
            try await self.write(response.data)
            self.server.log?("[\(address.address)] Response Command \(response.command) ID \(response.id) (\(response.data.count) bytes)")
        }
    }
}
