//
//  GoldUpdateRequest.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// Gold Update Request
/// Request to update the client's gold balance
public struct GoldUpdateRequest: GunBoundPacket, Encodable, Hashable {

    public static var opcode: Opcode { .goldUpdateRequest }

    public init() {}
}
