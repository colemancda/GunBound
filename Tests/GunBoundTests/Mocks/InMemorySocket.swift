import Foundation
@testable import GunBound
@testable import GunBoundProtocol

/// An in-memory, deterministic stand-in for `GunBoundSocketIPv4TCP` used by the
/// end-to-end client↔server tests. It satisfies the same `GunBoundSocketTCP`
/// contract the real socket does — the server's event-driven `Connection`
/// (`.read`/`.didWrite`/`.close`) and the client's direct `recieve`/`send`
/// read loop both drive off it — but the two endpoints exchange bytes through
/// in-process buffers instead of a real TCP loopback. That removes the file
/// descriptors whose non-blocking connect/accept races made the loopback
/// suites intermittently fail with "Bad file descriptor".
///
/// A `client(destination:)` call finds the `server(address:)` socket that
/// registered under the same address, mints a connected endpoint pair, hands
/// the server side to the listener's accept queue, and returns the client
/// side. Every packet a peer writes is delivered as one discrete chunk, so
/// framing is if anything cleaner than real TCP (the client still reassembles
/// by length header regardless).
actor InMemoryTCPSocket: GunBoundSocketTCP {

    enum Failure: Swift.Error { case connectionRefused }

    nonisolated let address: GunBound.GunBoundAddress
    private nonisolated let eventStream: GunBoundSocketEventStream
    private nonisolated let eventContinuation: GunBoundSocketEventStream.Continuation

    nonisolated var event: GunBoundSocketEventStream { eventStream }

    // Connected-endpoint state.
    private var peer: InMemoryTCPSocket?
    private var inbound: [Data] = []
    private var receiveWaiter: CheckedContinuation<Data, Never>?
    private var closed = false

    // Listening-endpoint state.
    private var pendingConnections: [InMemoryTCPSocket] = []
    private var acceptWaiter: CheckedContinuation<InMemoryTCPSocket, Never>?

    init(address: GunBound.GunBoundAddress) {
        self.address = address
        (self.eventStream, self.eventContinuation) = GunBoundSocketEventStream.makeStream()
    }

    // MARK: Factory

    static func server(address: GunBound.GunBoundAddress, backlog: Int) async throws -> InMemoryTCPSocket {
        let socket = InMemoryTCPSocket(address: address)
        await InMemoryTCPRegistry.shared.register(socket, at: address)
        return socket
    }

    static func client(
        address localAddress: GunBound.GunBoundAddress,
        destination: GunBound.GunBoundAddress
    ) async throws -> InMemoryTCPSocket {
        guard let listener = await InMemoryTCPRegistry.shared.listener(for: destination) else {
            throw Failure.connectionRefused
        }
        // Each connection gets a unique address so the server keys its
        // per-connection state (`storage.connections[address]`) distinctly —
        // exactly as two real clients on different ephemeral ports would.
        let clientAddress = await InMemoryTCPRegistry.shared.uniqueClientAddress()
        let clientEnd = InMemoryTCPSocket(address: clientAddress)
        let serverEnd = InMemoryTCPSocket(address: clientAddress)
        await clientEnd.setPeer(serverEnd)
        await serverEnd.setPeer(clientEnd)
        await listener.enqueueConnection(serverEnd)
        return clientEnd
    }

    // MARK: Connected endpoint

    func accept() async throws -> InMemoryTCPSocket {
        if !pendingConnections.isEmpty {
            return pendingConnections.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            self.acceptWaiter = continuation
        }
    }

    func send(_ data: Data) async throws {
        guard !closed, let peer else { throw Failure.connectionRefused }
        await peer.deliver(data)
        eventContinuation.yield(.didWrite(data.count))
    }

    func recieve(_ bufferSize: Int) async throws -> Data {
        if !inbound.isEmpty {
            return inbound.removeFirst()
        }
        if closed {
            return Data()  // EOF — the client read loop treats empty as close.
        }
        return await withCheckedContinuation { continuation in
            self.receiveWaiter = continuation
        }
    }

    func close() async {
        guard !closed else { return }
        closed = true
        if let waiter = receiveWaiter {
            receiveWaiter = nil
            waiter.resume(returning: Data())
        }
        eventContinuation.yield(.close)
        eventContinuation.finish()
        if let peer { await peer.peerDidClose() }
        peer = nil
    }

    // MARK: Internal wiring

    private func setPeer(_ peer: InMemoryTCPSocket) {
        self.peer = peer
    }

    /// Delivers one written chunk from the peer: a suspended reader takes it
    /// directly, otherwise it queues and a `.read` wakes the event loop.
    private func deliver(_ data: Data) {
        if let waiter = receiveWaiter {
            receiveWaiter = nil
            waiter.resume(returning: data)
        } else {
            inbound.append(data)
            eventContinuation.yield(.read)
        }
    }

    private func enqueueConnection(_ socket: InMemoryTCPSocket) {
        if let waiter = acceptWaiter {
            acceptWaiter = nil
            waiter.resume(returning: socket)
        } else {
            pendingConnections.append(socket)
        }
        eventContinuation.yield(.connection)
    }

    private func peerDidClose() {
        guard !closed else { return }
        closed = true
        if let waiter = receiveWaiter {
            receiveWaiter = nil
            waiter.resume(returning: Data())
        }
        eventContinuation.yield(.close)
        eventContinuation.finish()
    }
}

/// Maps a listening address to its in-memory server socket so `client(...)`
/// can find the `server(...)` it should connect to, and hands out a unique
/// synthetic address per client connection.
actor InMemoryTCPRegistry {

    static let shared = InMemoryTCPRegistry()

    private var listeners: [GunBound.GunBoundAddress: InMemoryTCPSocket] = [:]
    private var nextClientPort: UInt16 = 40000

    func register(_ socket: InMemoryTCPSocket, at address: GunBound.GunBoundAddress) {
        listeners[address] = socket
    }

    func listener(for address: GunBound.GunBoundAddress) -> InMemoryTCPSocket? {
        listeners[address]
    }

    func uniqueClientAddress() -> GunBound.GunBoundAddress {
        defer { nextClientPort = nextClientPort &+ 1 }
        return GunBound.GunBoundAddress(address: "127.0.0.1", port: nextClientPort)!
    }
}

/// A no-op UDP endpoint — the server constructs one but these tests exercise
/// no UDP traffic, so `recieve` never yields a datagram. It sleeps and throws
/// `CancellationError` so the server's UDP accept loop parks gently (matching
/// how the real socket's `resourceTemporarilyUnavailable` path idles) rather
/// than spinning.
actor InMemoryUDPSocket: GunBoundSocketUDP {

    nonisolated let address: GunBound.GunBoundAddress
    private nonisolated let eventStream: GunBoundSocketEventStream
    private nonisolated let eventContinuation: GunBoundSocketEventStream.Continuation

    nonisolated var event: GunBoundSocketEventStream { eventStream }

    init(address: GunBound.GunBoundAddress) async throws {
        self.address = address
        (self.eventStream, self.eventContinuation) = GunBoundSocketEventStream.makeStream()
    }

    func send(_ data: Data, to destination: GunBound.GunBoundAddress) async throws {}

    func recieve(_ bufferSize: Int) async throws -> (Data, GunBound.GunBoundAddress) {
        try await Task.sleep(nanoseconds: 100_000_000)
        throw CancellationError()
    }
}
