//
//  KeepAlive.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Keep Alive Packet
///
/// Used to maintain connection between client and server.
/// Sent periodically to prevent connection timeouts.
///
/// **Usage:**
/// Both client and server send this packet periodically to keep the
/// connection active. If a keep-alive packet is not received within
/// the timeout period, the connection is considered lost and terminated.
///
/// This packet contains no data - it's a simple heartbeat signal.
/// Typical interval is every 30-60 seconds depending on server configuration.
public struct KeepAlive: GunBoundPacket, Encodable, Hashable {

    public static var opcode: Opcode { .keepAlive }

    public init() {}
}
