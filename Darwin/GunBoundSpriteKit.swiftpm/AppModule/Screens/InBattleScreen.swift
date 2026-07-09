//
//  InBattleScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the minimal In-Battle stand-in (state 11) — just the stage
//  terrain sprite scaled to fit; the real battle renderer is the last piece
//  of the project and intentionally not built yet.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("In Battle") {
    inBattleScreenPreview()
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func inBattleScreenPreview() -> some View {
    let delegate = ScreenPreviewDelegate()
    return ScreenPreviewView(screen: InBattleScreen(viewModel: InBattleViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
