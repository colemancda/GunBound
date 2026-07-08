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
    let delegate = ScreenPreviewDelegate().withSampleRoom()
    return ScreenPreviewView(screen: ReadyRoomScreen(viewModel: ReadyRoomViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
