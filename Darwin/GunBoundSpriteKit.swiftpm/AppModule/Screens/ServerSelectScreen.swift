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
    serverSelectScreenPreview()
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func serverSelectScreenPreview() -> some View {
    let delegate = ScreenPreviewDelegate()
    let viewModel = ServerSelectViewModel(delegate: delegate)
    // Flip to the "connecting" wait state a moment after the screen enters
    // (onEnter resets the flag), so the preview also shows the
    // waitmessage.img overlay.
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        viewModel.isConnecting = true
    }
    return ScreenPreviewView(screen: ServerSelectScreen(viewModel: viewModel))
        .frame(width: 800, height: 600)
}
