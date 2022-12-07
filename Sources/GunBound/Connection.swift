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
    
    let encoder = GunBoundEncoder()
    
    let decoder = GunBoundDecoder()
    
    /// There's a pending incoming request.
    private var incomingRequest = false
    
    /// IDs for registered callbacks.
    private var nextRegisterID: UInt = 0
    
    /// IDs for "send" ops.
    private var nextSendOpcodeID: UInt = 0
    
    /// Pending request state.
    private var pendingRequest: SendOperation?
    
    /// Queued protocol requests
    private var requestQueue = [SendOperation]()
    
    /// Queued protocol indications
    private var indicationQueue = [SendOperation]()
    
    /// Queue of packets ready to send
    private var writeQueue = [SendOperation]()
    
    /// List of registered callbacks.
    private var notifyList = [NotifyType]()
    
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
        // handle packet
        
    }
    
    /// Performs the actual IO for sending data.
    @discardableResult
    internal func write() async throws -> Bool {
        guard let sendOperation = pickNextSendOpcode()
            else { return false }
        try await socket.send(sendOperation.data)
        let opcode = sendOperation.opcode
        /*
        switch opcode.type {
        case .request:
            pendingRequest = sendOperation
        case .indication:
            pendingRequest = sendOperation
        case .response:
            // Set `incomingRequest` to false to indicate that no request is pending
            incomingRequest = false
        case .command,
             .notification,
             .confirmation:
            break
        }
        */
        return true
    }
    
    // write all pending PDUs
    private func writePending() {
        Task(priority: .high) { [weak self] in
            guard let self = self, await self.isConnected else { return }
            do { try await self.write() } // event will call write again
            catch { log?("Unable to write. \(error)") }
        }
    }
    
    /// Registers a callback for an opcode and returns the ID associated with that callback.
    @discardableResult
    public func register <T> (_ callback: @escaping (T) async -> ()) -> UInt where T: GunBoundPacket, T: Decodable {
        
        let id = nextRegisterID
        
        // create notification
        let notify = Notify(id: id, notify: callback)
        
        // increment ID
        nextRegisterID += 1
        
        // add to queue
        notifyList.append(notify)
        
        return id
    }
    
    /// Unregisters the callback associated with the specified identifier.
    ///
    /// - Returns: Whether the callback was unregistered.
    @discardableResult
    public func unregister(_ id: UInt) -> Bool {
        
        guard let index = notifyList.firstIndex(where: { $0.id == id })
            else { return false }
        notifyList.remove(at: index)
        return true
    }
    
    /// Registers all callbacks.
    public func unregisterAll() {
        notifyList.removeAll()
    }
    
    private func pickNextSendOpcode() -> SendOperation? {
        
        // See if any operations are already in the write queue
        if let sendOpcode = writeQueue.popFirst() {
            return sendOpcode
        }
        
        // If there is no pending request, pick an operation from the request queue.
        if pendingRequest == nil,
            let sendOpcode = requestQueue.popFirst() {
            return sendOpcode
        }
        
        return nil
    }
    
    private func handle(notify data: Data, opcode: Opcode) async throws {
        
        var foundPDU: GunBoundPacket?
        
        let oldList = notifyList
        for notify in oldList {
            
            // try next
            if type(of: notify).packetType.opcode != opcode { continue }
            
            // attempt to deserialize
            guard let PDU = foundPDU ?? (try? type(of: notify).packetType.init(data: data, decoder: decoder))
                else { throw GunBoundError.invalidData(data) }
            
            foundPDU = PDU
            
            await notify.callback(PDU)
            
            // callback could remove all entries from notify list, if so, exit the loop
            if self.notifyList.isEmpty { break }
        }
        // TODO: Unsupported packets
        // If this was a request and no handler was registered for it, respond with "Not Supported"
        /*if foundPDU == nil && opcode.type == .request {
            let errorResponse = ATTErrorResponse(request: opcode, attributeHandle: 0x00, error: .requestNotSupported)
            let _ = queue(errorResponse)
        }*/
    }
}

internal final class SendOperation {
    
    /// The operation identifier.
    let id: UInt
    
    /// The request data.
    let data: Data
    
    /// The sent opcode
    let opcode: Opcode
    
    /// The response callback.
    let response: (callback: (GunBoundPacket) -> (), responseType: GunBoundPacket.Type)?
    
    fileprivate init(
        id: UInt,
        opcode: Opcode,
        data: Data,
        response: (callback: (GunBoundPacket) -> (),
                   responseType: GunBoundPacket.Type)? = nil
    ) {
        self.id = id
        self.opcode = opcode
        self.data = data
        self.response = response
    }
}

internal protocol NotifyType {
    
    static var packetType: (GunBoundPacket & Decodable).Type { get }
    
    var id: UInt { get }
    
    var callback: (GunBoundPacket) async -> () { get }
}

internal struct Notify<Packet>: NotifyType where Packet: GunBoundPacket, Packet: Decodable {
    
    static var packetType: (GunBoundPacket & Decodable).Type { return Packet.self }
    
    let id: UInt
    
    let notify: (Packet) async -> ()
    
    var callback: (GunBoundPacket) async -> () { return { await self.notify($0 as! Packet) } }
    
    init(id: UInt, notify: @escaping (Packet) async -> ()) {
        
        self.id = id
        self.notify = notify
    }
}
