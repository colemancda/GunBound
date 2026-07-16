//
//  AddBuddyDialogWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `AddBuddyDialogWidget` — the "add buddy ID" modal (buddy2.img
//  chrome, a prompt, a name field, and ADD / CLOSE buttons), opened from the
//  buddy panel's Add button. Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("AddBuddyDialogWidget") {
    WidgetPreviewView { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let dialog = AddBuddyDialogWidget(
            font: font,
            background: renderer.texture(named: "buddy2.img", assets: assets),
            addTexture: renderer.texture(named: "b_buddy2_addfriend1.img", assets: assets),
            closeTexture: renderer.texture(named: "b_buddy2_close.img", assets: assets)
        )
        dialog.nameField.setText("admin")
        return dialog
    }
}
