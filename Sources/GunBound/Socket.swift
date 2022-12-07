//
//  Socket.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Socket

/// GunBound Socket protocol
public protocol GunBoundSocket {
    
    var address: GunBoundAddress { get }
    
    /// Write to the socket.
    func send(_ data: Data) async throws
    
    /// Reads from the socket.
    func recieve(_ bufferSize: Int) async throws -> Data
    
    /// Attempt to accept an incoming connection.
    func accept() async throws -> Self
    
    static func client(
        address: GunBoundAddress,
        destination: GunBoundAddress
    ) async throws -> Self
    
    static func server(
        address: GunBoundAddress,
        backlog: Int
    ) async throws -> Self
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

public final class GunBoundTCPSocket {
    
    // MARK: - Properties
    
    public let address: GunBoundAddress
    
    @usableFromInline
    internal let socket: Socket
    
    // MARK: - Initialization
    
    deinit {
        Task(priority: .high) {
            await socket.close()
        }
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
        address: GunBoundAddress,
        destination: GunBoundAddress
    ) async throws -> Self {
        fatalError()
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
        let socketAddress = IPv4SocketAddress(address: address.ipAddress, port: address.port)
        return try self.init(socketProtocol, bind: socketAddress)
    }
    
    @usableFromInline
    func setNonblocking(retryOnInterrupt: Bool = true) throws {
        var flags = try getStatus(retryOnInterrupt: retryOnInterrupt)
        flags.insert(.nonBlocking)
        try setStatus(flags, retryOnInterrupt: retryOnInterrupt)
    }
}
