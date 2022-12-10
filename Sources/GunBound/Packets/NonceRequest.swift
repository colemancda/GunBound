//
//  NonceRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Nonce Request
public struct NonceRequest: GunBoundPacket, Equatable, Hashable, Codable {
    
    static public var opcode: Opcode { .nonceRequest }
    
    public init() { }
}
