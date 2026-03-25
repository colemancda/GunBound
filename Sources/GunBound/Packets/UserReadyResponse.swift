//
//  UserReadyResponse.swift
//
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

/// User Ready Response
///
/// Sent by the server in response to a UserReadyRequest.
/// Confirms the player's ready status has been updated.
///
/// **Usage:**
/// Sent after the server processes a ready status change.
/// The RTC (Return Code) indicates success or failure:
/// - 0x0000: Success
/// - Non-zero: Error code
public struct UserReadyResponse: GunBoundPacket, Equatable, Hashable, Codable {

    public static var opcode: Opcode { .roomUserReadyResponse }

    /// Return code (0x0000 = success)
    internal let rtc: UInt16

    public init() {
        self.rtc = 0x0000
    }
}
