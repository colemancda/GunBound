//
//  AvatarShopScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the Avatar Store (state 7) — a canned owned-item inventory
//  (sprites looked up by zero-padded item ID) over `store_back.img` with the
//  category tabs; tab hover/selection is interactive.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("Avatar Shop") {
    let delegate = ScreenPreviewDelegate()
    // This build's archives ship no per-item NNNNN.img sprites (stripped
    // private-server build), so the grid draws each item's ID in the bitmap
    // number font instead — same fallback the real app uses.
    delegate.session.avatar = PlayerAvatar(equipped: 0, inventory: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    return ScreenPreviewView(screen: AvatarShopScreen(viewModel: AvatarShopViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
