//
//  LoadingScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the Loading screen (state 10) — the sample room's map picks
//  the `load_stageNN.img` backdrop and its roster staggers to READY as the
//  simulated load progresses (then transition requests no-op in a preview,
//  so it just sits fully loaded).
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("Loading") {
    loadingScreenPreview()
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func loadingScreenPreview() -> some View {
    let delegate = ScreenPreviewDelegate().withSampleRoom()
    return ScreenPreviewView(screen: LoadingScreen(viewModel: LoadingViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
