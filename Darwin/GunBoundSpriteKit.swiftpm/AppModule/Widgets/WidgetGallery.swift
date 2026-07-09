//
//  WidgetGallery.swift
//  GunBoundSpriteKit
//
//  A #Preview for each `GunBoundClient` widget, hosted via `WidgetPreviewView`
//  (see WidgetPreview.swift). Each builds the widget with real bundled
//  textures so it renders as it does in-game, and is interactive in the canvas
//  (click, hover, type). Run `Darwin/copy-dependencies.sh` first so the
//  Resources folder is populated; an empty folder renders blank widgets.
//

import SwiftUI
import GunBound
import GunBoundProtocol
import GunBoundClient

// MARK: - ButtonWidget

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

// MARK: - ScrollBarWidget

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

// MARK: - TextFieldWidget

#Preview("TextFieldWidget") {
    WidgetPreviewView(width: 320, height: 90) { renderer, assets in
        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        let field = TextFieldWidget(frame: Rect(x: 20, y: 35, width: 280, height: 20), font: font)
        field.placeholder = "type here…"
        field.focus()
        return field
    }
}

// MARK: - DialogWidget (shared error/message popup)

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

// MARK: - BuddyPanelWidget

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

// MARK: - CreateRoomDialogWidget

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

// MARK: - EnterRoomNumberDialogWidget

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
