//
//  RoomSetTitleCommand.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

/// Room Change Option Command
public struct RoomSetTitleCommand: GunBoundPacket, Decodable, Equatable, Hashable {
    
    public static var opcode: Opcode { .roomSetTitleCommand }
    
    public var title: String
    
    public init(title: String) {
        self.title = title
    }
}

// MARK: - GunBoundDecodable

extension RoomSetTitleCommand: GunBoundDecodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        let data = try container.decode(Data.self, length: container.remainingBytes)
        guard let string = data.withUnsafeBytes({
            $0.baseAddress?.withMemoryRebound(to: Int8.self, capacity: data.count) {
                return String(cString: $0, encoding: .ascii)
            }
        }) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid string bytes"))
        }
        self.title = string
    }
}
