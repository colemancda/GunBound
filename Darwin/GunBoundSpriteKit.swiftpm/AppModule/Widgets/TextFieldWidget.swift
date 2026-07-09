//
//  TextFieldWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `TextFieldWidget` — focused with a blinking caret; type in the
//  canvas to edit (macOS). Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("TextFieldWidget") {
    WidgetPreviewView(width: 320, height: 90) { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let field = TextFieldWidget(frame: Rect(x: 20, y: 35, width: 280, height: 20), font: font)
        field.placeholder = "type here…"
        field.focus()
        return field
    }
}
