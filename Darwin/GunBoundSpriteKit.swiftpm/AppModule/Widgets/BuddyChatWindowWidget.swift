//
//  BuddyChatWindowWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `BuddyChatWindowWidget` — the 1-on-1 buddy "whisper" window
//  (buddy_window_back.img chrome, recipient name, message log, input, close-X).
//  Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("BuddyChatWindowWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let window = BuddyChatWindowWidget(
            recipient: "admin",
            font: font,
            background: renderer.texture(named: "buddy_window_back.img", assets: assets),
            closeTexture: renderer.texture(named: "b_buddywindow_exittalk.img", assets: assets)
        )
        window.messages = [
            ChatLine(sender: "admin", message: "hi"),
            ChatLine(sender: "you", message: "hey there"),
        ]
        return window
    }
}
