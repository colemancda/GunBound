//
//  GoldUpdateResponse.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Gold Update Response
/// Response containing updated gold balance
public struct GoldUpdateResponse: GunBoundPacket, Encodable, Hashable {

    public static var opcode: Opcode { .goldUpdateResponse }

    public var gold: UInt64

    public init(gold: UInt64 = 0) {
        self.gold = gold
    }
}
