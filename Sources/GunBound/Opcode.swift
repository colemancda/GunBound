//
//  Command.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation

/// Gunbound Packet Opcode
public enum Opcode: UInt16, Codable {
    
    /// Keep Alive
    case keepAlive                  = 0x0000
    
    /// Nonce Request
    case nonceRequest               = 0x1000
    
    /// Nonce Response
    case nonceResponse              = 0x1001
    
    /// Authentication Request
    case authenticationRequest      = 0x1310
    
    /// Authentication Response
    case authenticationResponse     = 0x1312
    
    /// Server Directory Request
    case serverDirectoryRequest     = 0x1100
    
    /// Server Directory Response
    case serverDirectoryResponse    = 0x1102
}

public extension Opcode {
    
    /// Specifies the opcode category.
    var type: OpcodeType {
        
        switch self {
        case .keepAlive:                            return .command
        case .nonceRequest:                         return .request
        case .nonceResponse:                        return .response
        case .authenticationRequest:                return .request
        case .authenticationResponse:               return .response
        case .serverDirectoryRequest:               return .request
        case .serverDirectoryResponse:              return .response
        }
    }
    
    /// Get the equivalent request for the current response opcode (if applicable).
    var request: Opcode? {
        return Opcode.requestsByResponse[self]
    }
    
    /// Get the equivalent response for the current request opcode (if applicable).
    var response: Opcode? {
        return Opcode.responsesByRequest[self]
    }
}

private extension Opcode {
    
    static let requestResponseMap: [(request: Opcode,  response: Opcode)] = [
        (nonceRequest,                  nonceResponse),
        (authenticationRequest,         authenticationResponse),
        (serverDirectoryRequest,        serverDirectoryResponse),
    ]
    
    static let responsesByRequest: [Opcode: Opcode] = {
        var dictionary = [Opcode: Opcode](minimumCapacity: requestResponseMap.count)
        requestResponseMap.forEach { dictionary[$0.request] = $0.response }
        return dictionary
    }()
    
    static let requestsByResponse: [Opcode: Opcode] = {
        var dictionary = [Opcode: Opcode](minimumCapacity: requestResponseMap.count)
        requestResponseMap.forEach { dictionary[$0.response] = $0.request }
        return dictionary
    }()
}

// MARK: - Supporting Types

public enum OpcodeType {
    
    case request
    case response
    case command
    case notification
}
