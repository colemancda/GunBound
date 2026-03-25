import Foundation

/// Get Avatar Response
///
/// Sent by the server in response to a GetAvatarRequest.
/// Contains the player's avatar inventory data.
///
/// **Opcode:** 0x6001
///
/// **Usage:**
/// Sent when the player requests their avatar inventory data.
/// The payload contains detailed information about all avatar items
/// owned by the player, including equipped items.
///
/// **Structure:**
/// The payload structure is: [RTC 2 bytes = 0x0000][AES-encrypted avatar data].
/// The avatar data is pre-encrypted by the handler before encoding,
/// so `Opcode.getAvatarResponse.isEncrypted` is intentionally `false`.
///
/// The encrypted avatar data includes:
/// - Equipped avatar bitmask
/// - List of owned avatar items
/// - Item quantities and properties
public struct GetAvatarResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .getAvatarResponse }

    /// Raw bytes: [0x00, 0x00] (RTC = return code, 0 = success) + encrypted avatar payload.
    /// The avatar data portion is AES-encrypted and must be decrypted by the client.
    internal let rtcAndEncryptedData: Data

    public init(rtcAndEncryptedData: Data) {
        self.rtcAndEncryptedData = rtcAndEncryptedData
    }

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(rtcAndEncryptedData)
    }
}
