//
//  ChannelUserListWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `ChannelUserListWidget` — the lobby's CHANNEL panel:
//  gamelist_channel chrome at the decomp rect with a sample roster and its
//  page-7 scrollbar. Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("ChannelUserListWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let panel = ChannelUserListWidget(
            font: font,
            background: renderer.texture(named: "gamelist_channel.img", assets: assets)
        )
        panel.users = (1...12).map { "player\($0)" }
        return panel
    }
}
