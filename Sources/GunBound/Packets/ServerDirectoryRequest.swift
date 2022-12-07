//
//  ServerDirectoryRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

public struct ServerDirectoryRequest: GunBoundPacket, Equatable, Hashable, Codable {
    
    public static var opcode: Opcode { .serverDirectoryRequest }
    
    let padding: UInt32 // 0x0000 by default
    
    public init() {
        self.padding = 0x0000
    }
}

extension ServerDirectoryRequest: GunBoundPacketEncodable {
    
    var expectedLength: Int { 4 }
}
