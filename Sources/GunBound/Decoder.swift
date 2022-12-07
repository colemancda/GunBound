//
//  Decoder.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// GunBound Packet Decoder
public struct GunBoundDecoder {
    
    // MARK: - Properties
    
    /// Any contextual information set by the user for encoding.
    public var userInfo = [CodingUserInfoKey : Any]()
    
    /// Logger handler
    public var log: ((String) -> ())?
    
    // MARK: - Initialization
    
    public init() { }
    
    // MARK: - Methods
    
    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable, T: GunBoundPacket {
        let opcode = T.opcode
        log?("Will decode \(opcode) packet")
        
        fatalError()
    }
}

