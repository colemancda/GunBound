//
//  KeepAlive.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Keep Alive Packet
/// Used to maintain connection between client and server
public struct KeepAlive: GunBoundPacket, Encodable, Hashable {

    public static var opcode: Opcode { .keepAlive }

    public init() {}
}
