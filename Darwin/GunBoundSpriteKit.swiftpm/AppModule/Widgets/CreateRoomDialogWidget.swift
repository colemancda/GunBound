//
//  CreateRoomDialogWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `CreateRoomDialogWidget` — the lobby's Create Room dialog:
//  gamelist_create chrome, name/password fields (click to focus, type to
//  edit), the click-to-cycle capacity, and yes/no buttons. Hosted via
//  WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("CreateRoomDialogWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let background = renderer.texture(named: "gamelist_create.img", assets: assets)
        let (w, h) = renderer.size(of: background)
        let frame = w > 0
            ? Rect(x: (800 - w) / 2, y: (600 - h) / 2, width: w, height: h)
            : Rect(x: 250, y: 190, width: 300, height: 220)
        let dialog = CreateRoomDialogWidget(
            frame: frame,
            font: font,
            background: background,
            okTexture: renderer.texture(named: "b_gamelist_yes.img", assets: assets),
            cancelTexture: renderer.texture(named: "b_gamelist_no.img", assets: assets)
        )
        dialog.nameField.setText("my room")
        return dialog
    }
}
