//
//  WorldServer.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Socket

public actor WorldServer {
        
    internal static let encoder = GunBoundEncoder()
    
    public init() {
        
    }
    
    public func handle(address: IPv4Address, packet: Packet) async -> Packet {
        
        NSLog(packet.description)
        NSLog(packet.data.toHexadecimal())
        
        do {
            switch packet.command {
            case .authenticationRequest:
                return try authenticate(packet)
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
    
    func authenticate(_ packet: Packet) throws -> Packet {
        //return try Self.encoder.encode(ServerDirectoryResponse(directory: directory))
        fatalError()
    }
}
