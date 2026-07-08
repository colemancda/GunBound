/// Logic for the Title screen (`titlemode.img`, `title.mp3`) — advances to
/// Server/Channel Select once the title music finishes playing, or
/// immediately on any input, matching the original's title-screen
/// "press any key" convention.
@MainActor
public final class TitleViewModel: ScreenViewModel {
    public let imageName = "titlemode.img"
    public let musicName: String? = "title.mp3"

    private let delegate: ViewModelDelegate

    /// Guards against reacting to `musicPlaybackChanged(isPlaying: false)`
    /// before playback has actually started (it's `false` both before the
    /// track starts and after it finishes) — set once the track is
    /// confirmed playing.
    private var hasConfirmedPlaying = false

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {
        hasConfirmedPlaying = false
    }

    public func onExit() {}

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerDown, .activate:
            delegate.requestTransition(to: .serverSelect)
        case .pointerMoved:
            break
        }
    }

    public func update(deltaTime: Double) {}

    /// Called by the view every frame with whether the title music is
    /// currently playing — audio playback is platform-specific, so this
    /// signal comes from outside rather than this view model polling it
    /// itself. Once playback was confirmed and then stops, advances onward.
    public func musicPlaybackChanged(isPlaying: Bool) {
        if isPlaying {
            hasConfirmedPlaying = true
        } else if hasConfirmedPlaying {
            delegate.requestTransition(to: .serverSelect)
        }
    }
}
