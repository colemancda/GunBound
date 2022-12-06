//
//  BrokerServer.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

public actor BrokerServer {
    
    public var directory: ServerDirectory
    
    public init(directory: ServerDirectory) {
        self.directory = directory
    }
    
    public func update<T>(_ body: (inout ServerDirectory) -> (T)) -> T {
        return body(&directory)
    }
    
    func handle(_ packet: Packet) async -> Packet {
        switch packet.command {
        case .serverDirectoryRequest:
            fatalError()
        default:
            fatalError()
        }
    }
}
