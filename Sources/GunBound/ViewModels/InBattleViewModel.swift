/// Logic for the minimal In-Battle stand-in (state 11) — the real client's
/// render pipeline here is a full Direct3D7 + software-blit hybrid driving
/// tanks, turns, weapons, and networked player state (see
/// `ARCHITECTURE.md`'s rendering section); all of that is out of scope for
/// this pass. This just identifies the stage terrain sprite to draw
/// (scaled to fit, by the view) and returns to the Game Room List on any
/// input.
@MainActor
public final class InBattleViewModel: ScreenViewModel {
    /// Real stage terrain sprite confirmed to exist and be full stage-sized
    /// (1800x1800) in `graphics.xfs` — not derived from `stage.dat`, since
    /// the stage-name-to-terrain-image mapping isn't reverse-engineered yet
    /// (see `FILEFORMATS.md`).
    public static let stageImageName = "cave.img"
    public let backgroundImageName = InBattleViewModel.stageImageName

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {}
    public func onExit() {}
    public func update(deltaTime: Double) {}

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerDown, .activate:
            delegate.requestTransition(to: .gameRoomList)
        case .pointerMoved, .text, .key:
            break
        }
    }
}
