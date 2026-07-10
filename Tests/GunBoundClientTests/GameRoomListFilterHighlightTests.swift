import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundFile

/// Verifies the Game Room List draws the *active* filter button's yellow
/// ("active") frame — frame 4 of `b_gamelist_viewall.img` / `wait.img`.
@Suite @MainActor
struct GameRoomListFilterHighlightTests {

    /// A `ClientTexture` that remembers which `(name, frame)` it was made for,
    /// so a draw can be traced back to the exact sprite frame requested.
    private final class FrameTex: ClientTexture {
        let name: String
        let frame: Int
        init(_ name: String, _ frame: Int) { self.name = name; self.frame = frame }
    }

    /// Records every draw as `(texture, rect)` and never fails to produce a
    /// texture, so `onEnter` completes without any real assets.
    private final class RecordingRenderer: ClientRenderer {
        var draws: [(tex: FrameTex, rect: Rect)] = []
        func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? {
            FrameTex(name, frameIndex)
        }
        func texture(from frame: ImgFile.Frame) -> ClientTexture? { FrameTex("<inline>", 0) }
        func size(of texture: ClientTexture?) -> (width: Float, height: Float) { (100, 100) }
        func clear() {}
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float) {
            if let tex = texture as? FrameTex { draws.append((tex, rect)) }
        }
        func present() {}
    }

    private func makeContext(_ renderer: ClientRenderer) -> ClientContext {
        // A dummy asset directory: the screen's only direct asset touch is a
        // `try?`-guarded thumbnail count, so a missing dir is fine.
        let assets = AssetLibrary(directory: URL(fileURLWithPath: "/nonexistent", isDirectory: true))
        let network = NetworkConfig(username: "u", password: "p", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        return ClientContext(assets: assets, renderer: renderer, network: network) {
            NullAudioPlayer()
        }
    }

    /// The View All button's decomp rect (`GameRoomListViewModel.buttons`).
    private let viewAllRect = Rect(x: 42, y: 246, width: 81, height: 33)
    private let waitRect = Rect(x: 131, y: 246, width: 81, height: 33)

    @Test func viewAllShowsActiveFrameByDefault() throws {
        let renderer = RecordingRenderer()
        let context = makeContext(renderer)
        let viewModel = GameRoomListViewModel(delegate: context)
        let screen = GameRoomListScreen(viewModel: viewModel)

        try screen.onEnter(context: context)
        try screen.render(renderer)

        // The default filter is `.all`, so View All must draw its active
        // (yellow) frame and Waiting its normal (blue) frame.
        let viewAll = renderer.draws.last { $0.rect == viewAllRect }
        let wait = renderer.draws.last { $0.rect == waitRect }
        #expect(viewAll?.tex.name == "b_gamelist_viewall.img")
        #expect(viewAll?.tex.frame == ButtonState.selected.frame)  // 4
        #expect(wait?.tex.frame == 0)
    }

    @Test func togglingToWaitingMovesTheHighlight() throws {
        let renderer = RecordingRenderer()
        let context = makeContext(renderer)
        let viewModel = GameRoomListViewModel(delegate: context)
        let screen = GameRoomListScreen(viewModel: viewModel)
        try screen.onEnter(context: context)

        // Toggle to Waiting Only, as clicking the button does.
        viewModel.handle(.pointerDown(x: waitRect.x + 1, y: waitRect.y + 1))
        viewModel.handle(.pointerUp(x: waitRect.x + 1, y: waitRect.y + 1))

        renderer.draws.removeAll()
        try screen.render(renderer)

        let viewAll = renderer.draws.last { $0.rect == viewAllRect }
        let wait = renderer.draws.last { $0.rect == waitRect }
        #expect(wait?.tex.frame == ButtonState.selected.frame)  // 4
        #expect(viewAll?.tex.frame == 0)
    }
}

/// A `ClientAudioPlayer` that does nothing — screens create one on enter.
@MainActor
private final class NullAudioPlayer: ClientAudioPlayer {
    func play(named name: String, assets: AssetLibrary, loop: Bool) {}
    func playEffect(named name: String, assets: AssetLibrary) -> Bool { false }
    func stop() {}
    var isPlaying: Bool { false }
    func update(deltaTime: Double) {}
}
