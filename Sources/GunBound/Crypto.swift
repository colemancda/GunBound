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
    
    static var login: Key { Key([0xFF, 0xB3, 0xB3, 0xBE, 0xAE, 0x97, 0xAD, 0x83, 0xB9, 0x61, 0x0E, 0x23, 0xA4, 0x3C, 0x2E, 0xB0]) }
    
    static var commandLine: Key { Key([0xFA, 0xEE, 0x85, 0xF2, 0x40, 0x73, 0xD9, 0x16, 0x13, 0x90, 0x19, 0x7F, 0x6E, 0x56, 0x2A, 0x67]) }
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
