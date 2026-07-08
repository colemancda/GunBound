//
//  LogoScreen.swift
//  GunBoundSpriteKit
//
//  Created by Alsey Coleman Miller on 7/8/26.
//

import SwiftUI
import SpriteKit
import GunBound
import GunBoundClient

/// SwiftUI view that renders the publisher splash screen via SpriteKit,
/// reusing the same `LogoScreen`/`LogoViewModel` types as the full SDL client.
struct LogoScreenView: View {
    private let scene: LogoSKScene

    init(viewModel: LogoViewModel, assetsDirectory: URL) {
        let s = LogoSKScene(viewModel: viewModel, assetsDirectory: assetsDirectory)
        s.scaleMode = .aspectFit
        self.scene = s
    }

    var body: some View {
        SpriteView(scene: scene)
            .aspectRatio(GameScene.canvasSize, contentMode: .fit)
    }
}

/// Hosts a single `LogoScreen` in its own `SKScene`, mirroring `GameScene`'s
/// update/render loop but scoped to just the publisher splash.
private final class LogoSKScene: SKScene {
    private let viewModel: LogoViewModel
    private let assetsDirectory: URL
    private var screen: GunBoundClient.LogoScreen?
    private var renderer: SpriteKitRenderer?
    private var lastUpdateTime: TimeInterval?

    init(viewModel: LogoViewModel, assetsDirectory: URL) {
        self.viewModel = viewModel
        self.assetsDirectory = assetsDirectory
        super.init(size: GameScene.canvasSize)
        backgroundColor = .black
        anchorPoint = .zero
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        let renderer = SpriteKitRenderer(scene: self)
        let assets = AssetLibrary(directory: assetsDirectory)
        let network = NetworkConfig(
            username: "",
            password: "",
            serverAddress: "127.0.0.1",
            serverPort: 8370,
            brokerPort: 8372
        )
        let context = ClientContext(assets: assets, renderer: renderer, network: network) {
            SpriteKitAudioPlayer()
        }
        self.renderer = renderer
        let screen = GunBoundClient.LogoScreen(viewModel: viewModel)
        try? screen.onEnter(context: context)
        self.screen = screen
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let screen, let renderer else { return }
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        screen.update(deltaTime: deltaTime)
        try? screen.render(renderer)
    }
}

/// Mirrors `MockViewModelDelegate` from `GunBoundTests` — records transitions
/// and quit requests rather than driving a real SDL/network stack.
@MainActor
private final class PreviewDelegate: ViewModelDelegate {
    let network = NetworkConfig(
        username: "admin",
        password: "1234",
        serverAddress: "127.0.0.1",
        serverPort: 8370,
        brokerPort: 8372
    )
    var client: NetworkClient<GunBoundSocketIPv4TCP>?
    let session = ClientSession()

    func requestTransition(to mode: ClientMode) {}
    func requestQuit() {}
}

#Preview {
    let delegate = PreviewDelegate()
    let viewModel = LogoViewModel(
        imageName: "logomode.img",
        musicName: nil,
        next: .logo2,
        delegate: delegate
    )
    let resourceURL = Bundle.main.resourceURL ?? URL(filePath: ".")
    let assetsDirectory = resourceURL.appendingPathComponent("Resources")
    return LogoScreenView(viewModel: viewModel, assetsDirectory: assetsDirectory)
        .frame(width: 800, height: 600)
}
