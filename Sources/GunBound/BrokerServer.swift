//
//  BrokerServer.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Socket

public actor BrokerServer {
    
    public var directory: ServerDirectory
    
    internal static let encoder = GunBoundEncoder()
    
    public init(directory: ServerDirectory) {
        self.directory = directory
    }
    
    public func update<T>(_ body: (inout ServerDirectory) -> (T)) -> T {
        return body(&directory)
    }
    
    public func handle(address: IPv4Address, packet: Packet) async -> Packet {
        do {
            switch packet.opcode {
            case .serverDirectoryRequest:
                return try serverDirectory()
            default:
                fatalError()
            }
        } catch {
            fatalError()
        }
    }
    
    func errorResponse(_ error: Error) -> Packet {
        fatalError()
    }
    
    func serverDirectory() throws -> Packet {
        return try Self.encoder.encode(ServerDirectoryResponse(directory: directory))
    }
}
