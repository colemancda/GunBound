//
//  RoomChangeItemCommand.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Room Change Item Command
/// Command to change the item state in a room
public struct RoomChangeItemCommand: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .roomChangeUseItemCommand }

    public var itemState: UInt16

    public init(itemState: UInt16 = 0) {
        self.itemState = itemState
    }
}
