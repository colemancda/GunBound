//
//  BuddyPanelWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `BuddyPanelWidget` — the shared buddy list: buddy_back chrome,
//  a sample roster, Add/Del/close-X buttons, and the right-edge scrollbar.
//  Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("BuddyPanelWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let background = renderer.texture(named: "buddy_back.img", assets: assets)
        let (w, h) = renderer.size(of: background)
        let panel = BuddyPanelWidget(
            frame: Rect(x: (800 - w) / 2, y: (600 - h) / 2, width: w, height: h),
            font: font,
            background: background,
            addTexture: renderer.texture(named: "b_buddy_plus.img", assets: assets),
            delTexture: renderer.texture(named: "b_buddy_del.img", assets: assets),
            closeTexture: renderer.texture(named: "b_buddy_exit.img", assets: assets)
        )
        panel.buddies = ["alsey", "boomer", "trico", "mage", "armor", "grub", "aduka"]
        return panel
    }
}
