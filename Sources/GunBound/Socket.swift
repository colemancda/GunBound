//
//  Socket.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Socket

/// GunBound Socket protocol
public protocol GunBoundSocketTCP {
    
    /// Socket address
    var address: GunBoundAddress { get }
    
    /// Event stream
    var event: GunBoundSocketEventStream { get }
    
    /// Write to the socket.
    func send(_ data: Data) async throws
    
    /// Reads from the socket.
    func recieve(_ bufferSize: Int) async throws -> Data
    
    /// Attempt to accept an incoming connection.
    func accept() async throws -> Self
    
    /// Close immediately.
    func close() async
    
    static func client(
        address: GunBoundAddress,
        destination: GunBoundAddress
    ) async throws -> Self
    
    static func server(
        address: GunBoundAddress,
        backlog: Int
    ) async throws -> Self
}

public protocol GunBoundSocketUDP {
    
    /// Initialize with address
    init(address: GunBoundAddress) async throws
    
    /// Socket address
    var address: GunBoundAddress { get }
    
    /// Event stream
    var event: GunBoundSocketEventStream { get }
    
    /// Write to the socket.
    func send(_ data: Data, to destination: GunBoundAddress) async throws
    
    /// Reads from the socket.
    func recieve(_ bufferSize: Int) async throws -> (Data, GunBoundAddress)
}

/// GunBound Socket Event
public enum GunBoundSocketEvent {
    
    case pendingRead
    case read(Int)
    case write(Int)
    case close(Error?)
}

public typealias GunBoundSocketEventStream = AsyncStream<GunBoundSocketEvent>

// MARK: - Implementation

public final class GunBoundSocketIPv4TCP: GunBoundSocketTCP {
    
    // MARK: - Properties
    
    public let address: GunBoundAddress
    
    @usableFromInline
    internal let socket: Socket
    
    public var event: GunBoundSocketEventStream {
        let stream = self.socket.event
        var iterator = stream.makeAsyncIterator()
        return GunBoundSocketEventStream(unfolding: {
            await iterator
                .next()
                .map { .init($0) }
        })
    }
    
    // MARK: - Initialization
    
    deinit {
        // TODO: Fix crash
        /*
        Task(priority: .high) {
            await socket.close()
        }
         */
    }
    
    internal init(
        socket: Socket,
        address: GunBoundAddress
    ) {
        self.socket = socket
        self.address = address
    }
    
    internal init(
        fileDescriptor: SocketDescriptor,
        address: GunBoundAddress
    ) async {
        self.socket = await Socket(fileDescriptor: fileDescriptor)
        self.address = address
    }
    
    public static func client(
        address localAddress: GunBoundAddress,
        destination destinationAddress: GunBoundAddress
    ) async throws -> Self {
        let fileDescriptor = try SocketDescriptor.tcp(localAddress) // [.closeOnExec, .nonBlocking])
        try await fileDescriptor.closeIfThrows {
            try fileDescriptor.setNonblocking()
            try await fileDescriptor.connect(to: IPv4SocketAddress(destinationAddress), sleep: 100_000_000)
        }
        return await Self(
            fileDescriptor: fileDescriptor,
            address: localAddress
        )
    }
    
    public static func server(
        address: GunBoundAddress,
        backlog: Int = 100
    ) async throws -> Self {
        let fileDescriptor = try SocketDescriptor.tcp(address) // [.closeOnExec, .nonBlocking])
        try fileDescriptor.closeIfThrows {
            try fileDescriptor.listen(backlog: backlog)
            try fileDescriptor.setNonblocking()
        }
        return await Self(
            fileDescriptor: fileDescriptor,
            address: address
        )
    }
    
    // MARK: - Methods
    
    public func accept() async throws -> Self {
        let (clientFileDescriptor, clientAddress) = try await socket.fileDescriptor.accept(IPv4SocketAddress.self, sleep: 100_000_000)
        try clientFileDescriptor.closeIfThrows {
            try clientFileDescriptor.setNonblocking()
        }
        let address = GunBoundAddress(
            ipAddress: clientAddress.address,
            port: clientAddress.port
        )
        return await Self(
            fileDescriptor: clientFileDescriptor,
            address: address
        )
    }
    
    /// Write to the socket.
    public func send(_ data: Data) async throws {
        try await socket.write(data)
    }
    
    /// Reads from the socket.
    public func recieve(_ bufferSize: Int) async throws -> Data {
        return try await socket.read(bufferSize)
    }
    
    public func close() async {
        await socket.close()
    }
}

public final class GunBoundSocketIPv4UDP: GunBoundSocketUDP {
    
    // MARK: - Properties
    
    public let address: GunBoundAddress
    
    @usableFromInline
    internal let socket: Socket
    
    public var event: GunBoundSocketEventStream {
        let stream = self.socket.event
        var iterator = stream.makeAsyncIterator()
        return GunBoundSocketEventStream(unfolding: {
            await iterator
                .next()
                .map { .init($0) }
        })
    }
    
    // MARK: - Initialization
    
    deinit {
        Task(priority: .high) {
            await socket.close()
        }
    }
    
    public init(address: GunBoundAddress) async throws {
        let fileDescriptor = try SocketDescriptor.udp(address)
        try fileDescriptor.closeIfThrows {
            try fileDescriptor.setNonblocking()
        }
        self.address = address
        self.socket = await Socket(fileDescriptor: fileDescriptor)
    }
    
    // MARK: - Methods
    
    public func send(_ data: Data, to destination: GunBoundAddress) async throws {
        try await socket.sendMessage(data, to: IPv4SocketAddress(destination))
    }
    
    public func recieve(_ bufferSize: Int) async throws -> (Data, GunBoundAddress) {
        let (data, address) = try await socket.receiveMessage(bufferSize, fromAddressOf: IPv4SocketAddress.self)
        return (data, GunBoundAddress(ipAddress: address.address, port: address.port))
    }
}

internal extension GunBoundSocketEvent {
    
    init(_ event: Socket.Event) {
        switch event {
        case .pendingRead:
            self = .pendingRead
        case let .read(bytes):
            self = .read(bytes)
        case let .write(bytes):
            self = .write(bytes)
        case let .close(error):
            self = .close(error)
        }
    }
}

internal extension SocketDescriptor {
    
    /// Creates a TCP socket binded to the specified address.
    @usableFromInline
    static func tcp(
        _ address: GunBoundAddress
    ) throws -> SocketDescriptor {
        let socketProtocol = IPv4Protocol.tcp
        let socketAddress = IPv4SocketAddress(address)
        return try self.init(socketProtocol, bind: socketAddress)
    }
    
    /// Creates a UDP socket binded to the specified address.
    @usableFromInline
    static func udp(
        _ address: GunBoundAddress
    ) throws -> SocketDescriptor {
        let socketProtocol = IPv4Protocol.udp
        let socketAddress = IPv4SocketAddress(address)
        return try self.init(socketProtocol, bind: socketAddress)
    }
    
    @usableFromInline
    func setNonblocking(retryOnInterrupt: Bool = true) throws {
        var flags = try getStatus(retryOnInterrupt: retryOnInterrupt)
        flags.insert(.nonBlocking)
        try setStatus(flags, retryOnInterrupt: retryOnInterrupt)
    }
}
