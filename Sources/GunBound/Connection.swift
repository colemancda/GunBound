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
        
    let encoder = GunBoundEncoder()
    
    let decoder = GunBoundDecoder()
    
    private var didAuthenticate = false
    
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
            catch {
                log?("Unable to read. \(error)")
                await self.socket.close()
            }
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
        
        // parse packet
        guard let packet = Packet(data: recievedData, validateOpcode: false) else {
            throw GunBoundError.invalidData(recievedData)
        }
        
        // validate opcode
        guard let opcode = Opcode(rawValue: packet.opcodeRawValue) else {
            log?("Recieved unknown opcode 0x\(packet.opcodeRawValue.toHexadecimal())")
            return
        }
        assert(packet.opcode == opcode)
        
        log?("Recieved packet \(packet.opcode) ID \(packet.id)")
        
        // handle packet
        switch opcode.type {
        case .response:
            try await handle(response: packet)
        case .request:
            try await handle(request: packet)
        case .command, .notification:
            // For all other opcodes notify the upper layer of the PDU and let them act on it.
            try await handle(notify: packet)
        }
    }
    
    /// Performs the actual IO for sending data.
    @discardableResult
    internal func write() async throws -> Bool {
        
        // get next write operation
        guard let sendOperation = pickNextSendOpcode()
            else { return false }
        
        // encode packet
        var packet = try encoder.encode(sendOperation.packet, id: 0x0000)
        
        // use special ID for first login
        self.sentBytes += packet.data.count
        if didAuthenticate == false, type(of: sendOperation.packet).opcode == .authenticationRequest {
            packet.id = .login
        } else {
            packet.id = .init(serverPacketLength: Int(sentBytes))
        }
        
        // write data to socket
        try await socket.send(packet.data)
        
        // wait for pending response
        switch packet.opcode.type {
        case .request:
            pendingRequest = sendOperation
        case .response:
            // Set `incomingRequest` to false to indicate that no request is pending
            incomingRequest = false
        case .command, .notification:
            break
        }
        
        return true
    }
    
    // write all pending PDUs
    private func writePending() {
        Task(priority: .high) { [weak self] in
            guard let self = self, await self.isConnected else { return }
            do { try await self.write() }
            catch {
                log?("Unable to write. \(error)")
                await self.socket.close()
            }
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
    
    /// Adds a packet to the queue to send.
    ///
    /// - Returns: Identifier of queued send operation or `nil` if the packet cannot be sent.
    @discardableResult
    public func queue <T> (
        _ packet: T,
        response: (callback: (GunBoundPacket) -> (), GunBoundPacket.Type)? = nil
    ) -> UInt? where T: GunBoundPacket, T: Encodable {
        
        // Only request PDUs should have response callbacks.
        switch T.opcode.type {
        case .request:
            
            guard response != nil
                else { return nil }
            
        case .response,
             .command,
             .notification:
            
            guard response == nil
                else { return nil }
        }
        
        // increment ID
        let id = nextSendOpcodeID
        nextSendOpcodeID += 1
        
        let sendOpcode = SendOperation(
            id: id,
            packet: packet,
            response: response
        )
        
        // Add the op to the correct queue based on its type
        switch T.opcode.type {
        case .request:
            requestQueue.append(sendOpcode)
        case .response,
             .command,
             .notification:
            writeQueue.append(sendOpcode)
        }
        
        writePending()
        
        return sendOpcode.id
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
    
    private func handle(notify packet: Packet) async throws {
        
        var foundPDU: GunBoundPacket?
        
        let oldList = notifyList
        for notify in oldList {
            
            // try next opcode
            guard type(of: notify).packetType.opcode == packet.opcode else {
                continue
            }
            
            // attempt to deserialize
            guard let PDU = foundPDU ?? (try? type(of: notify).packetType.init(packet: packet, decoder: decoder))
                else { throw GunBoundError.invalidData(packet.data) }
            
            foundPDU = PDU
            
            await notify.callback(PDU)
            
            // callback could remove all entries from notify list, if so, exit the loop
            if self.notifyList.isEmpty { break }
        }
        // TODO: Unsupported packets
        // If this was a request and no handler was registered for it, respond with "Not Supported"
        if foundPDU == nil && packet.opcode.type == .request {
            //let errorResponse = ATTErrorResponse(request: opcode, attributeHandle: 0x00, error: .requestNotSupported)
            //let _ = queue(errorResponse)
        }
    }
    
    private func handle(response packet: Packet) async throws {
        
        // If no request is pending, then the response is unexpected. Disconnect the bearer.
        guard let sendOperation = self.pendingRequest else {
            throw GunBoundError.invalidData(packet.data)
        }
        
        // If the received response doesn't match the pending request, or if the request is malformed,
        // end the current request with failure.
                
        guard let requestOpcode = packet.opcode.request
            else { throw GunBoundError.unexpectedResponse(packet.data) }
                
        // clear current pending request
        defer { self.pendingRequest = nil }
        
        /// Verify the recieved response belongs to the pending request
        guard type(of: sendOperation.packet).opcode == requestOpcode else {
            throw GunBoundError.invalidData(packet.data)
        }
        
        // success!
        try sendOperation.handleResponse(packet)
        
        writePending()
    }
    
    private func handle(request packet: Packet) async throws {
        
        /*
        * If a request is currently pending, then the sequential
        * protocol was violated. Disconnect the bearer, which will
        * promptly notify the upper layer via disconnect handlers.
        */
        
        // Received request while another is pending.
        guard incomingRequest == false
            else { throw GunBoundError.invalidData(packet.data) }
        
        incomingRequest = true
        
        // notify
        try await handle(notify: packet)
    }
}

internal final class SendOperation {
    
    /// The operation identifier.
    let id: UInt
    
    /// The packet to send.
    let packet: any (GunBoundPacket & Encodable)
    
    /// The response callback.
    let response: (callback: (GunBoundPacket) -> (), responseType: GunBoundPacket.Type)?
    
    fileprivate init(
        id: UInt,
        packet: any (GunBoundPacket & Encodable),
        response: (callback: (GunBoundPacket) -> (),
                   responseType: GunBoundPacket.Type)? = nil
    ) {
        self.id = id
        self.packet = packet
        self.response = response
    }
}

extension SendOperation {
    
    func handleResponse(_ packet: Packet) throws {
        // TODO: Handle response
        /*
        guard let responseInfo = self.response
            else { throw GunBoundError.unexpectedResponse(data) }
        
        guard let opcode = data.first.flatMap(Opcode.init(rawValue:))
            else { throw GunBoundError.invalidData(data) }
        
        if opcode == .errorResponse {
            
            guard let errorResponse = ErrorResponse(data: data)
                else { throw GunBoundError.invalidData(data) }
            
            responseInfo.callback(errorResponse)
            
        } else if opcode == responseInfo.responseType.attributeOpcode {
            
            guard let response = responseInfo.responseType.init(data: data)
                else { throw GunBoundError.invalidData(data) }
            
            responseInfo.callback(response)
            
        } else {
            // other response
            throw GunBoundError.unexpectedResponse(packet.data)
        }*/
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
