//
//  ServerDirectoryRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Server Directory Response
///
/// Sent by the server in response to a ServerDirectoryRequest.
/// Contains a list of available game servers for the client to choose from.
///
/// **Usage:**
/// Sent after the client requests the server directory.
/// The client displays this list to allow the player to select
/// which game server to connect to.
///
/// Each server entry includes:
/// - Server name and description
/// - Network address and port
/// - Current utilization and capacity
/// - Whether the server is enabled/available
public struct ServerDirectoryResponse: GunBoundPacket, Equatable, Hashable, Encodable {

    public static var opcode: Opcode { .serverDirectoryResponse }

    /// List of available game servers
    public let directory: ServerDirectory

    public init(directory: ServerDirectory = []) {
        self.directory = directory
    }
}

extension ServerDirectoryResponse: GunBoundEncodable {

    public func encode(to container: GunBoundEncodingContainer) throws {

        // unknown
        try container.encode(UInt8(0x00))
        try container.encode(UInt8(0x00))
        try container.encode(UInt8(0x01))

        // number of servers
        try container.encode(UInt8(directory.count))

        // encode each
        for (index, server) in directory.enumerated() {
            // Server Index
            try container.encode(UInt8(index))
            try container.encode(UInt8(0x00))
            try container.encode(UInt8(0x00))
            // values
            try container.encode(server.name, forKey: ServerDirectory.Element.CodingKeys.name)
            try container.encode(server.descriptionText, forKey: ServerDirectory.Element.CodingKeys.descriptionText)
            try container.encode(server.address, forKey: ServerDirectory.Element.CodingKeys.address)
            try container.encode(server.port, isLittleEndian: false)
            try container.encode(server.utilization, isLittleEndian: false)
            try container.encode(server.utilization, isLittleEndian: false)
            try container.encode(server.capacity, isLittleEndian: false)
            try container.encode(server.isEnabled, forKey: ServerDirectory.Element.CodingKeys.isEnabled)

        }
    }
}
