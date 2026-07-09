//
//  InBattleScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the In-Battle static scene (state 11, slice 1) — a sample
//  match on Metropolis: the stage world through the camera, four mobiles at
//  their spawns with team-colored name tags (one dead, grayed), and the
//  turn HUD. Move the pointer to a screen edge to pan the camera.
//

import SwiftUI
import GunBound
import GunBoundProtocol
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
    func player(_ id: UInt8, _ name: Username, _ mobile: Mobile, _ team: Team, x: UInt16, turn: UInt16) -> StartGameNotification.Player {
        StartGameNotification.Player(
            id: id, username: name, team: team, primaryTank: mobile, secondaryTank: .random,
            xPosition: x, yPosition: 900, turnOrder: turn
        )
    }
    delegate.session.battle = StartGameNotification(
        settings: 0,
        map: .metropolis,
        players: [
            player(0, "admin", .boomer, .a, x: 500, turn: 0),
            player(1, "trico", .trico, .a, x: 760, turn: 2),
            player(2, "guest", .armor, .b, x: 1040, turn: 1),
            player(3, "mage", .mage, .b, x: 1300, turn: 3),
        ],
        events: 0,
        commandData: []
    )
    let viewModel = InBattleViewModel(delegate: delegate)
    let screen = InBattleScreen(viewModel: viewModel)
    // One casualty so the grayed dead-state is visible.
    viewModel.onEnter()
    viewModel.apply(.playerDied(PlayerDeadNotification(slot: 3, team: .b)))
    return ScreenPreviewView(screen: screen)
        .frame(width: 800, height: 600)
}
