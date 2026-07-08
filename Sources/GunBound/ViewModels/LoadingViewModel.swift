/// Logic for the Loading screen (state 10) — real client shows per-player
/// ready icons here; this pass just holds a fixed short duration before
/// advancing to the (also minimal) In-Battle level render, since there's no
/// session/player-ready networking to wait on yet.
@MainActor
public final class LoadingViewModel: ScreenViewModel {
    public let backgroundImageName = "load_back.img"
    public let stageOverlayImageName = "load_stage00.img"

    private let duration: Double = 1.2
    private var elapsed: Double = 0
    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {
        elapsed = 0
    }

    public func onExit() {}

    public func handle(_ event: ScreenInputEvent) {}

    public func update(deltaTime: Double) {
        elapsed += deltaTime
        if elapsed >= duration {
            delegate.requestTransition(to: .inGameSession)
        }
    }
}
