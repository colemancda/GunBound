/// Logic for the publisher splash screens (states 5/6 in the decomp's
/// `CGameState` table) — auto-advances after a fixed duration (matching
/// `ARCHITECTURE.md`'s "~2 second, non-interactive publisher splash" note),
/// or immediately on any input.
@MainActor
public final class LogoViewModel: ScreenViewModel {
    public let imageName: String
    public let musicName: String?
    public let next: ClientMode

    private let duration: Double
    private let delegate: ViewModelDelegate
    private var elapsed: Double = 0

    public init(imageName: String, musicName: String?, duration: Double = 2.5, next: ClientMode, delegate: ViewModelDelegate) {
        self.imageName = imageName
        self.musicName = musicName
        self.duration = duration
        self.next = next
        self.delegate = delegate
    }

    public func onEnter() {
        elapsed = 0
    }

    public func onExit() {}

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerDown, .activate:
            delegate.requestTransition(to: next)
        case .pointerMoved, .pointerUp, .text, .key, .scroll:
            break
        }
    }

    public func update(deltaTime: Double) {
        elapsed += deltaTime
        if elapsed >= duration {
            delegate.requestTransition(to: next)
        }
    }
}
