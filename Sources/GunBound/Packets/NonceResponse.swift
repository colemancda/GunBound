//
//  NonceResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

public struct NonceResponse: GunBoundPacket, Equatable, Hashable, Codable {
    
    public static var opcode: Opcode { .nonceResponse }
    
    public let nonce: Nonce
    
    public init(nonce: Nonce = Nonce()) {
        self.nonce = nonce
    }
}

extension NonceResponse: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(nonce.rawValue, isLittleEndian: false)
    }
}
