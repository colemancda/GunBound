//
//  Crypto.swift
//  
//
//  Created by Alsey Coleman Miller on 12/7/22.
//

import Foundation
import CryptoSwift

// MARK: - Key

public struct Key {
    
    public let data: Data
    
    internal init<C>(_ data: C) where C: Collection, C.Element == UInt8 {
        self.data = Data(data)
    }
}

public extension Key {
    
    static let login = Key([0xFF, 0xB3, 0xB3, 0xBE, 0xAE, 0x97, 0xAD, 0x83, 0xB9, 0x61, 0x0E, 0x23, 0xA4, 0x3C, 0x2E, 0xB0])
}

// MARK: - Encryption

internal struct Crypto {
    
    struct AES {
        
        static func decrypt(_ data: Data, key: Key) throws -> Data {
            let aes = try CryptoSwift.AES(key: .init(key.data), blockMode: ECB(), padding: .zeroPadding)
            let decrypted = try aes.decrypt(.init(data))
            return Data(decrypted)
        }
    }
    
    struct SHA0 {
        
        func process(_ block: Data) {
            
        }
    }
}
