//
//  TitleScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the Title screen (state 1) — `titlemode.img`, advance on tap.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("Title") {
    titleScreenPreview()
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func titleScreenPreview() -> some View {
    let delegate = ScreenPreviewDelegate()
    return ScreenPreviewView(screen: TitleScreen(viewModel: TitleViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
