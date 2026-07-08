//
//  ServerSelectScreen.swift
//  GunBoundSpriteKit
//
//  Preview for Server / Channel Select (state 2) — the WORLD LIST panel over
//  `server_back.img` with the three confirmed buttons. No broker is running
//  in a preview, so clicking Server falls back to the configured address and
//  fails quietly; hover states are interactive.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("Server Select") {
    let delegate = ScreenPreviewDelegate()
    return ScreenPreviewView(screen: ServerSelectScreen(viewModel: ServerSelectViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
