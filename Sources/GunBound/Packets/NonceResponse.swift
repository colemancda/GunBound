//
//  NonceResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Nonce Response
///
/// Sent by the server in response to a NonceRequest.
/// Contains a cryptographic nonce value for secure authentication.
///
/// **Usage:**
/// Sent during the authentication handshake process.
/// The nonce is a random value that the client uses to encrypt
/// authentication credentials before sending AuthenticationRequest.
///
/// This ensures each authentication session is unique and prevents
/// replay attacks where intercepted credentials could be reused.
///
/// **Note:** The filename has a typo ("Nonce" instead of "Nonce"),
/// but this is kept for compatibility with original codebase.
public struct NonceResponse: GunBoundPacket, Equatable, Hashable, Codable {

    public static var opcode: Opcode { .nonceResponse }

    /// A random nonce value (big-endian, 4 bytes)
    /// Used for encrypting authentication credentials
    public var nonce: Nonce

    public init(nonce: Nonce = Nonce()) {
        self.nonce = nonce
    }
}

extension NonceResponse: GunBoundEncodable {

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(nonce.rawValue, isLittleEndian: false)
    }
}
