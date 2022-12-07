//
//  Connection.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Socket

/// GunBound Connection
internal actor Connection <Socket: GunBoundSocket> {
    
    let socket: Socket
    
    let log: ((String) -> ())?
    
    let didDisconnect: ((Error?) async -> ())?
    
    var isConnected = true
    
    var sentBytes = 0
    
    var recievedBytes = 0
    
    let nonce = Nonce()
    
    
    
    // MARK: - Initialization
    
    public init(
        socket: Socket,
        log: ((String) -> ())? = nil,
        didDisconnect: ((Error?) async -> ())? = nil
    ) async {
        self.socket = socket
        self.log = log
        self.didDisconnect = didDisconnect
        run()
    }
    
    // MARK: - Methods
    
    private func run() {
        Task.detached(priority: .high) { [weak self] in
            guard let stream = self?.socket.event else { return }
            for await event in stream {
                await self?.socketEvent(event)
            }
            // socket closed
        }
    }
    
    private func socketEvent(_ event: GunBoundSocketEvent) async {
        switch event {
        case .pendingRead:
            #if DEBUG
            log?("Pending read")
            #endif
            do { try await read() }
            catch { log?("Unable to read. \(error)") }
        case let .read(byteCount):
            #if DEBUG
            log?("Did read \(byteCount) bytes")
            #endif
        case let .write(byteCount):
            #if DEBUG
            log?("Did write \(byteCount) bytes")
            #endif
            // try to write again
            do { try await write() }
            catch { log?("Unable to write. \(error)") }
        case let .close(error):
            #if DEBUG
            log?("Did close. \(error?.localizedDescription ?? "")")
            #endif
            isConnected = false
            await didDisconnect?(error)
        }
    }
    
    /// Performs the actual IO for recieving data.
    internal func read() async throws {
        // read packet
        let bytesToRead = Packet.maxSize
        let recievedData = try await socket.recieve(bytesToRead)
        self.recievedBytes += recievedData.count
        guard let packet = Packet(data: recievedData) else {
            throw GunBoundError.invalidData(recievedData)
        }
        
    }
    
    /// Performs the actual IO for sending data.
    @discardableResult
    internal func write() async throws -> Bool {
        fatalError()
    }
}
