/// Logic for the Game Room List / channel lobby (state 3) — "Create" and
/// "Avatar" transition locally to the Ready Room / Avatar Shop; "Join"/
/// "Ranking"/"Buddy" have no local-only screen to go to (they're
/// server-driven lists/dialogs) so they just log the click — none of this
/// is wired to any protocol packets yet (no room-list networking here).
@MainActor
public final class GameRoomListViewModel: ScreenViewModel {
    public struct Button: Equatable, Sendable {
        public let name: String
        public var rect: Rect = .zero
    }

    public let backgroundImageName = "gamelist_back.img"

    public private(set) var buttons: [Button] = [
        Button(name: "gamelist_create.img"),
        Button(name: "b_gamelist_join.img"),
        Button(name: "b_gamelist_ranking.img"),
        Button(name: "b_gamelist_avatar.img"),
        Button(name: "b_gamelist_buddy.img"),
    ]

    public private(set) var hoveredIndex: Int?

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {
        hoveredIndex = nil
    }

    public func onExit() {
        hoveredIndex = nil
    }

    public func update(deltaTime: Double) {}

    /// The view calls this once it knows the loaded texture's size for the
    /// button at `index` (buttons are laid out left-to-right by the view;
    /// this view model only stores the resulting hit-testing rect).
    public func setRect(_ rect: Rect, forButtonAt index: Int) {
        guard buttons.indices.contains(index) else { return }
        buttons[index].rect = rect
    }

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredIndex = buttons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            guard let index = buttons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) else { return }
            let name = buttons[index].name
            print("[GunBound] clicked room-list button: \(name)")
            switch name {
            case "gamelist_create.img":
                delegate.requestTransition(to: .readyRoom)
            case "b_gamelist_avatar.img":
                delegate.requestTransition(to: .avatarShop)
            default:
                break
            }

        case .activate:
            break
        }
    }
}
