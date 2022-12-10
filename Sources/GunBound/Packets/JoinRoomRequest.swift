//
//  JoinRoomRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Join Room request
public struct JoinRoomRequest: GunBoundPacket, Codable, Equatable, Hashable {
    
    public static var opcode: Opcode { .joinRoomRequest }
    
    public var room: Room.ID
    
    public var password: String?
    
    public init(
        room: Room.ID,
        password: String? = nil
    ) {
        self.room = room
        self.password = password
    }
}

// MARK: - GunBoundCodable

extension JoinRoomRequest: GunBoundCodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        self.room = try container.decode(Room.ID.self, forKey: CodingKeys.room)
        if container.remainingBytes > 0 {
            let data = try container.decode(Data.self, length: container.remainingBytes)
            guard let string = data.withUnsafeBytes({
                $0.baseAddress?.withMemoryRebound(to: Int8.self, capacity: data.count) {
                    return String(cString: $0, encoding: .ascii)
                }
            }) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid string bytes"))
            }
            self.password = string.isEmpty ? nil : string
        } else {
            self.password = nil
        }
    }
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(room, forKey: CodingKeys.room)
        try container.encode(password ?? "", fixedLength: 4)
    }
}
