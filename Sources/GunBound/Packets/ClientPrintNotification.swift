//
//  ClientPrintNotification.swift
//
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation

/// Client Print Notification
///
/// Sent by the server to display a message to the client.
/// This is typically used for system messages, notifications, or alerts.
///
/// **Usage:**
/// The client should display the message in a prominent location,
/// such as a popup dialog or system notification area.
/// This is separate from chat messages and is used for important
/// information that requires player attention.
public struct ClientPrintNotification: GunBoundPacket, Encodable, Equatable, Hashable {

    public static var opcode: Opcode { .clientPrintNotification }

    /// The message text to display to the client
    public let message: String
}
