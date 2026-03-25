//
//  RoomSelectTankResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/9/22.
//

import Foundation

/// Room Select Tank Response
///
/// Sent by the server in response to a RoomSelectTankRequest.
/// Acknowledges successful mobile/tank selection.
///
/// **Usage:**
/// Sent after successfully processing a mobile selection request.
/// The RTC field indicates the result:
/// - 0x00: Success
/// - Non-zero: Error (e.g., invalid mobile, game already started)
///
/// After receiving this, the client knows their mobile selection
/// has been updated and other players will be notified via
/// RoomUpdateNotification.
public struct RoomSelectTankResponse: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .roomSelectTankResponse }

    /// Return code (0x00 = success, non-zero = error)
    public let rtc: UInt16

    public init() {
        self.rtc = 0x00
    }
}
