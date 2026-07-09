//
//  LobbyChatWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `LobbyChatWidget` — the lobby chat panel: gamelist_chat
//  chrome at the decomp rect, sample history following the tail, and the
//  input line (click it and type on macOS; Enter "sends" to the console).
//  Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("LobbyChatWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let panel = LobbyChatWidget(
            font: font,
            background: renderer.texture(named: "gamelist_chat.img", assets: assets)
        )
        panel.messages = [
            "alsey: anyone up for a match?",
            "boomer: rookie zone is open",
            "trico: gg last round",
            "mage: brb",
        ]
        panel.onSend = { print("[preview] chat send: \($0)") }
        panel.inputField.focus()
        return panel
    }
}
