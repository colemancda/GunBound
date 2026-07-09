//
//  EnterRoomNumberDialogWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `EnterRoomNumberDialogWidget` — the lobby's "enter room by
//  number" dialog: gamelist_directgo chrome, a digits-only field, and yes/no
//  buttons. Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("EnterRoomNumberDialogWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let background = renderer.texture(named: "gamelist_directgo.img", assets: assets)
        let (w, h) = renderer.size(of: background)
        let frame = w > 0
            ? Rect(x: (800 - w) / 2, y: (600 - h) / 2, width: w, height: h)
            : Rect(x: 260, y: 210, width: 280, height: 180)
        let dialog = EnterRoomNumberDialogWidget(
            frame: frame,
            font: font,
            background: background,
            okTexture: renderer.texture(named: "b_gamelist_yes.img", assets: assets),
            cancelTexture: renderer.texture(named: "b_gamelist_no.img", assets: assets)
        )
        dialog.numberField.setText("42")
        return dialog
    }
}
