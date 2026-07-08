//
//  ReadyRoomScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the pre-battle Ready Room (state 9) — the sample session
//  provides a joined room with a 4-player roster (names + teams in the
//  bitmap font) over the map/character-select chrome.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("Ready Room") {
    readyRoomScreenPreview()
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func readyRoomScreenPreview() -> some View {
    let delegate = ScreenPreviewDelegate().withSampleRoom()
    return ScreenPreviewView(screen: ReadyRoomScreen(viewModel: ReadyRoomViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
