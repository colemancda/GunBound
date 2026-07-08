/// Logic for the pre-battle Ready Room (state 9) — reached from the Game
/// Room List's "Create" button. No battle/session logic here — just the
/// map/character-select chrome plus cancel/start button hit-testing
/// (game session is out of scope).
@MainActor
public final class ReadyRoomViewModel: ScreenViewModel {
    public let backgroundImageName = "ready_selectmap.img"
    public let characterSelectImageName = "ready_selectcharacter.img"
    public let startButtonImageName = "b_ready_startgame.img"
    public let cancelButtonImageName = "b_ready_cancel.img"

    public var startRect: Rect = .zero
    public var cancelRect: Rect = .zero

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {}
    public func onExit() {}
    public func update(deltaTime: Double) {}

    public func handle(_ event: ScreenInputEvent) {
        guard case .pointerDown(let x, let y) = event else { return }
        if cancelRect.contains(x: x, y: y) {
            delegate.requestTransition(to: .gameRoomList)
        } else if startRect.contains(x: x, y: y) {
            delegate.requestTransition(to: .loading)
        }
    }
}
