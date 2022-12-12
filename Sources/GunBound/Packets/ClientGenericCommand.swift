//
//  ClientGenericCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation

/// Client Generic Command
public struct ClientGenericCommand: GunBoundPacket, Decodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .clientGenericCommand }
    
    internal let value0: UInt8
    
    public let command: String
}

// MARK: - GunBoundDecodable

extension ClientGenericCommand: GunBoundDecodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        self.value0 = try container.decode(UInt8.self)
        self.command = try container.decode(length: container.remainingBytes) {
            String(data: $0, encoding: .ascii)
        }
    }
}
