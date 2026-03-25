//
//  PlayerResurrectCommand.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Player Resurrect Command
/// Command sent when a player resurrects in-game
public struct PlayerResurrectCommand: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .playResurrect }

    public static var isEncrypted: Bool { true }

    /// Empty payload - the packet is encrypted but has no meaningful data
    public init() {}
}
