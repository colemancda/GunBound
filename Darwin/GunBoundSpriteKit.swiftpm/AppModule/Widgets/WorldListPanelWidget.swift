//
//  WorldListPanelWidget.swift
//  GunBoundSpriteKit
//
//  Preview for `WorldListPanelWidget` — Server Select's WORLD LIST panel
//  (the port of the decomp's CWorldListPanel): the server-row grid, the
//  View All / Friends tab pair, and the row scrollbar (with b_scroll arrow
//  buttons), in one widget. Hosted via WidgetPreview.swift.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("WorldListPanelWidget") {
    WidgetPreviewView { renderer, assets in
        let delegate = ScreenPreviewDelegate()
        let viewModel = ServerSelectViewModel(
            delegate: delegate,
            directoryFetcher: MockDirectoryFetcher(servers: mockServers)
        )
        // Size the panel from its chrome, like the screen's onEnter does, then
        // load the list so rows populate a frame later.
        let panelTexture = renderer.texture(named: viewModel.panelImageName, assets: assets)
        let (panelWidth, panelHeight) = renderer.size(of: panelTexture)
        viewModel.panelRect = Rect(x: 11, y: 13, width: panelWidth, height: panelHeight)
        Task { _ = await viewModel.fetchDirectoryAndChooseServer() }

        let font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
        return WorldListPanelWidget(
            viewModel: viewModel,
            font: font,
            panelTexture: panelTexture,
            rowBaseTexture: renderer.texture(named: viewModel.panelImageName, frame: 1, assets: assets),
            rowSelectedTexture: renderer.texture(named: viewModel.panelImageName, frame: 3, assets: assets),
            rowOfflineTexture: renderer.texture(named: viewModel.panelImageName, frame: 4, assets: assets),
            gaugeTextures: (5...9).map { renderer.texture(named: viewModel.panelImageName, frame: $0, assets: assets) },
            viewAllSprite: ButtonSprite(name: "b_server_all.img", renderer: renderer, assets: assets),
            friendsSprite: ButtonSprite(name: "b_server_friend.img", renderer: renderer, assets: assets),
            scrollUpSprite: ButtonSprite(name: "b_scroll_up.img", renderer: renderer, assets: assets),
            scrollDownSprite: ButtonSprite(name: "b_scroll_down.img", renderer: renderer, assets: assets)
        )
    }
}
