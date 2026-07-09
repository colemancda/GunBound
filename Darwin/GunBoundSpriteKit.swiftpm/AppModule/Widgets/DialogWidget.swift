//
//  DialogWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `DialogWidget` — the shared error/message popup: error_back
//  chrome, a word-wrapped message, and the b_error_confirm OK button (click
//  or press Return to dismiss). Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("DialogWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let background = renderer.texture(named: "error_back.img", assets: assets)
        let (w, h) = renderer.size(of: background)
        let frame = Rect(x: (800 - w) / 2, y: (600 - h) / 2, width: w, height: h)
        let confirm = renderer.texture(named: "b_error_confirm.img", assets: assets)
        let (cw, ch) = renderer.size(of: confirm)
        let dialog = DialogWidget(
            frame: frame,
            message: "Could not connect to the server. Please try again in a moment.",
            font: font,
            background: background,
            confirmFrame: Rect(x: frame.x + (frame.width - cw) / 2, y: frame.y + frame.height - ch - 12, width: cw, height: ch),
            confirmTexture: confirm
        )
        return dialog
    }
}
