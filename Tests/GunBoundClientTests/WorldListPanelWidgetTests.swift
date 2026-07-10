import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundFile

@Suite @MainActor
struct WorldListPanelWidgetTests {

    /// Records draws as `(frame, rect)` so a tab draw can be traced to the
    /// exact button-state frame; never returns nil so sprites resolve.
    private final class FrameTex: ClientTexture {
        let frame: Int
        init(_ frame: Int) { self.frame = frame }
    }
    private final class RecordingRenderer: ClientRenderer {
        var draws: [(frame: Int, rect: Rect)] = []
        func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? { FrameTex(frameIndex) }
        func texture(from frame: ImgFile.Frame) -> ClientTexture? { FrameTex(0) }
        func size(of texture: ClientTexture?) -> (width: Float, height: Float) { (10, 10) }
        func clear() {}
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float) {
            if let tex = texture as? FrameTex { draws.append((tex.frame, rect)) }
        }
        func present() {}
    }

    private func makeViewModel() -> ServerSelectViewModel {
        let network = NetworkConfig(username: "u", password: "p", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let assets = AssetLibrary(directory: URL(fileURLWithPath: "/nonexistent", isDirectory: true))
        let context = ClientContext(assets: assets, renderer: RecordingRenderer(), network: network) {
            FakeAudio()
        }
        let viewModel = ServerSelectViewModel(delegate: context)
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        return viewModel
    }

    private func makeWidget(_ viewModel: ServerSelectViewModel, _ renderer: ClientRenderer) -> WorldListPanelWidget {
        let assets = AssetLibrary(directory: URL(fileURLWithPath: "/nonexistent", isDirectory: true))
        return WorldListPanelWidget(
            viewModel: viewModel,
            font: nil,
            panelTexture: nil,
            rowBaseTexture: nil,
            rowSelectedTexture: nil,
            rowOfflineTexture: nil,
            gaugeTextures: [],
            viewAllSprite: ButtonSprite(name: "b_server_all.img", renderer: renderer, assets: assets),
            friendsSprite: ButtonSprite(name: "b_server_friend.img", renderer: renderer, assets: assets),
            scrollUpSprite: ButtonSprite(name: "b_scroll_up.img", renderer: renderer, assets: assets),
            scrollDownSprite: ButtonSprite(name: "b_scroll_down.img", renderer: renderer, assets: assets)
        )
    }

    private let viewAllRect = Rect(x: 336, y: 504, width: 74, height: 26)
    private let friendsRect = Rect(x: 430, y: 504, width: 74, height: 26)

    @Test func drawsTheActiveViewTabInItsSelectedFrame() {
        let viewModel = makeViewModel()  // default worldListFilter == .all
        let renderer = RecordingRenderer()
        let widget = makeWidget(viewModel, renderer)

        widget.drawSelf(renderer)

        // View All is the active view → its selected (yellow) frame 4; Friends
        // is inactive → default frame 0.
        let viewAll = renderer.draws.last { $0.rect == viewAllRect }
        let friends = renderer.draws.last { $0.rect == friendsRect }
        #expect(viewAll?.frame == ButtonState.selected.frame)  // 4
        #expect(friends?.frame == 0)
    }

    @Test func consumesTabClicksAndForwardsToTheViewModel() {
        let viewModel = makeViewModel()
        let widget = makeWidget(viewModel, RecordingRenderer())

        // A press on the Friends tab is consumed by the panel.
        let consumed = widget.handleSelf(.pointerDown(x: friendsRect.x + 2, y: friendsRect.y + 2))
        #expect(consumed)

        // A press outside the tabs/rows isn't consumed (falls through to the
        // screen's bottom-bar handling).
        let elsewhere = widget.handleSelf(.pointerDown(x: 5, y: 560))
        #expect(!elsewhere)
    }

    @Test func hostsTheScrollbarAsAChild() {
        let viewModel = makeViewModel()
        let widget = makeWidget(viewModel, RecordingRenderer())
        #expect(widget.children.contains { $0 is ScrollBarWidget })
    }
}

@MainActor
private final class FakeAudio: ClientAudioPlayer {
    func play(named name: String, assets: AssetLibrary, loop: Bool) {}
    func playEffect(named name: String, assets: AssetLibrary) -> Bool { false }
    func stop() {}
    var isPlaying: Bool { false }
    func update(deltaTime: Double) {}
}
