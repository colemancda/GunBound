//
//  CashUpdate.swift
//
//
//  Created by Alsey Coleman Miller on 12/8/22.
//

import Foundation

/// Cash Update Notification
///
/// Sent by the server to update the client's current cash balance.
/// This is typically sent after purchases or when cash is awarded.
///
/// **Usage:**
/// The client should update its cached cash balance when receiving this packet.
/// This ensures the UI displays the correct amount of available cash.
///
/// **Note:** This packet is encrypted before transmission.
public struct CashUpdate: GunBoundPacket, Encodable, Hashable {

    public static var opcode: Opcode { .cashUpdateNotification }

    public static var isEncrypted: Bool { true }

    /// The player's current cash balance (real currency)
    public let cash: UInt32

    public init(cash: UInt32 = 0) {
        self.cash = cash
    }
}
