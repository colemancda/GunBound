//
//  GoldUpdateRequest.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Gold Update Request
///
/// Sent by the client to request the current gold balance.
/// The server responds with a GoldUpdateResponse containing the balance.
///
/// **Usage:**
/// Used when the client needs to refresh its cached gold balance,
/// typically after purchases, game rewards, or when opening the shop.
/// The server sends the player's current gold amount in the response.
public struct GoldUpdateRequest: GunBoundPacket, Encodable, Hashable {

    public static var opcode: Opcode { .goldUpdateRequest }

    public init() {}
}
