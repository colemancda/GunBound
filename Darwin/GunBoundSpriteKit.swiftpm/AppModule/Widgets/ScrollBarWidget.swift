//
//  ScrollBarWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `ScrollBarWidget` — 40 items over a 6-line page, arrows step
//  the position and the stand-in thumb tracks it. Hosted via
//  WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("ScrollBarWidget") {
    WidgetPreviewView(width: 120, height: 320) { renderer, assets in
        let bar = ScrollBarWidget(track: Rect(x: 44, y: 20, width: 28, height: 280), arrowSize: 24)
        bar.contentCount = 40
        bar.pageSize = 6
        // Any small sprite stands in for the thumb so the position is visible.
        bar.thumbTexture = renderer.texture(named: "b_buddy_exit.img", assets: assets)
        bar.onScroll = { print("[preview] scrolled to \($0)") }
        return bar
    }
}
