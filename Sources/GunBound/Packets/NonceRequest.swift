//
//  NonceRequest.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Nonce Request
///
/// Sent by the client to request a cryptographic nonce from the server.
/// Used in the authentication handshake process.
///
/// **Usage:**
/// Sent before authentication to establish a secure session.
/// The server responds with a random nonce value that is used
/// for encrypting authentication credentials.
///
/// The nonce ensures that each authentication session is unique
/// and prevents replay attacks.
///
/// **Note:** The filename has a typo ("Nonce" instead of "Nonce"),
/// but this is kept for compatibility with the original codebase.
public struct NonceRequest: GunBoundPacket, Equatable, Hashable, Codable {

    static public var opcode: Opcode { .nonceRequest }

    public init() {}
}
