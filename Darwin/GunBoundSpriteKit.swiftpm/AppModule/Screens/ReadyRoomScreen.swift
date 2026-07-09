//
//  ReadyRoomScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the pre-battle Ready Room (state 9) — the sample session
//  provides a joined room with a 4-player roster (portraits, names, teams)
//  around the center map panel, plus room chat and the decomp bottom bar.
//  The picker toggle (small button at the chat panel's top-left corner)
//  swaps the chat for the character grid.
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
    let viewModel = ReadyRoomViewModel(delegate: delegate)
    viewModel.chatMessages = [
        ChatLine(sender: "boomer", message: "glhf"),
        ChatLine(message: "The match will begin shortly.", type: .notice),
        ChatLine(sender: "trico", message: "ready when you are"),
    ]
    return ScreenPreviewView(screen: ReadyRoomScreen(viewModel: viewModel))
        .frame(width: 800, height: 600)
}
