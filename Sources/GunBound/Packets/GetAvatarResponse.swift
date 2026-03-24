import Foundation

/// Get Avatar Response (0x6001)
///
/// The payload structure is: [RTC 2 bytes = 0x0000][AES-encrypted avatar data].
/// The handler pre-encrypts the avatar data so Connection.swift does not touch it.
/// `Opcode.getAvatarResponse.isEncrypted` is intentionally `false`.
public struct GetAvatarResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .getAvatarResponse }

    /// Raw bytes: [0x00, 0x00] (RTC) + encrypted avatar payload.
    internal let rtcAndEncryptedData: Data

    public init(rtcAndEncryptedData: Data) {
        self.rtcAndEncryptedData = rtcAndEncryptedData
    }

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(rtcAndEncryptedData)
    }
}
