//
//  NonceResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

public struct NonceResponse: GunBoundPacket {
    
    public static var command: Command { .nonceResponse }
    
    public let nonce: Nonce
    
    public init(nonce: Nonce = Nonce()) {
        self.nonce = nonce
    }
}

