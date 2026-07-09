//
//  GameRoomListScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the Game Room List / channel lobby (state 3) — room cards are
//  injected directly (no live server in a preview), showing the 3x2 grid,
//  status icons, and bitmap-font room numbers/counts/names.
//

import SwiftUI
import GunBound
import GunBoundProtocol
import GunBoundClient

#Preview("Game Room List") {
    gameRoomListScreenPreview()
}

#Preview("Game Room List — Buddy Panel") {
    gameRoomListScreenPreview(showBuddyPanel: true)
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func gameRoomListScreenPreview(showBuddyPanel: Bool = false) -> some View {
    let delegate = ScreenPreviewDelegate()
    let viewModel = GameRoomListViewModel(delegate: delegate)
    if showBuddyPanel {
        viewModel.buddies = [
            "alsey", "boomer", "trico", "mage", "armor",
            "grub", "aduka", "kalsiddon", "jd", "bigfoot", "raon",
        ]
        viewModel.setBuddyPanelVisible(true)
    }
    // `RoomSettings(gameMode:)` picks the card's mode label (SOLO/SCORE/TAG/
    // JEWEL); `isLocked` shows the padlock; `isPlaying`/fullness pick
    // PLAY/FULL/WAIT.
    viewModel.rooms = [
        RoomListResponse.Room(id: 1, name: "Rookie zone", map: .metropolis, settings: RoomSettings(gameMode: .solo).rawValue, playerCount: 2, capacity: ._2_2, isPlaying: false, isLocked: false),
        RoomListResponse.Room(id: 2, name: "Avatar ON come in", map: .miramoTown, settings: RoomSettings(gameMode: .score).rawValue, playerCount: 8, capacity: ._4_4, isPlaying: false, isLocked: false),
        RoomListResponse.Room(id: 3, name: "1 vs 1 pros only", map: .seaHero, settings: RoomSettings(gameMode: .tag).rawValue, playerCount: 1, capacity: ._1_1, isPlaying: true, isLocked: false),
        RoomListResponse.Room(id: 4, name: "password is 1234", map: .dragon, settings: RoomSettings(gameMode: .jewel).rawValue, playerCount: 3, capacity: ._4_4, isPlaying: false, isLocked: true),
        RoomListResponse.Room(id: 5, name: "no cheats", map: .nirvana, settings: RoomSettings(gameMode: .solo).rawValue, playerCount: 4, capacity: ._3_3, isPlaying: true, isLocked: false),
        RoomListResponse.Room(id: 6, name: "GG only", map: .random, settings: RoomSettings(gameMode: .jewel).rawValue, playerCount: 6, capacity: ._4_4, isPlaying: false, isLocked: true),
    ]
    // Mark room 5 as the player's own joined room, so it renders in the joined
    // card frame.
    delegate.session.currentRoom = JoinRoomResponse(
        room: 5, name: "no cheats", map: .nirvana, settings: 0, capacity: ._3_3, players: []
    )
    // The CHANNEL panel's roster (normally seeded from the join-channel
    // response and grown by 0x200E pushes).
    viewModel.channelUsers = ["alsey", "boomer", "trico", "mage", "armor", "grub", "aduka", "kalsiddon"]
    return ScreenPreviewView(screen: GameRoomListScreen(viewModel: viewModel))
        .frame(width: 800, height: 600)
}
