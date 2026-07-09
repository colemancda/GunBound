//
//  ButtonWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `ButtonWidget` — a clickable leaf drawn with real button art,
//  hover-tinted in the canvas. Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("ButtonWidget") {
    WidgetPreviewView(width: 260, height: 110) { renderer, assets in
        let texture = renderer.texture(named: "b_gamelist_create.img", assets: assets)
        let (w, h) = renderer.size(of: texture)
        let button = ButtonWidget(
            frame: Rect(x: 20, y: 30, width: max(w, 100), height: max(h, 40)),
            texture: texture
        )
        button.onClick = { print("[preview] button clicked") }
        return button
    }
}
