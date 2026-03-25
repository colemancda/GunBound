//
//  UserReadyRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

/// User Ready Request
///
/// Sent by the client to indicate ready status to the server.
/// The server updates the ready status and broadcasts to all players in the room.
public struct UserReadyRequest: GunBoundPacket, Equatable, Hashable, Codable {

    public static var opcode: Opcode { .roomUserReadyRequest }

    /// Whether the player is ready to start gameplay
    public var isReady: Bool

    public init(isReady: Bool) {
        self.isReady = isReady
    }
}
