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
/// Sent after successfully processing a mobile selection
    public init() {
        self.rtc = 0x00
    }
}
