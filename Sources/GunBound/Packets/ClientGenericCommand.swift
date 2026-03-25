//
//  ClientGenericCommand.swift
//
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation

/// Client Generic Command
///
/// Sent by the client to execute a generic command on the server.
/// This packet allows sending arbitrary command strings for processing.
///
/// **Usage:**
/// Used for various client-initiated commands that don't have dedicated packet types.
/// The command string is parsed by the server to determine the action to take.
///
/// **Note:** The value0 field's purpose is currently unknown and may be unused.
public struct ClientGenericCommand: GunBoundPacket, Decodable, Equatable, Hashable {

    public static var opcode: Opcode { .clientCommand }

    /// Unknown field (purpose not yet determined)
    internal let value0: UInt8

    /// The command string to execute
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
