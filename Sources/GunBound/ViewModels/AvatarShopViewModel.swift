/// Logic for the Avatar Store / Shop (state 7) — reached from the Game Room
/// List's "Avatar" button. Category buttons are hit-testable, but don't
/// wire up to any purchase flow — no networking/inventory logic in this
/// pass.
@MainActor
public final class AvatarShopViewModel: ScreenViewModel {
    public struct Button: Equatable, Sendable {
        public let name: String
        public var rect: Rect = .zero
    }

    public let backgroundImageName = "store_back.img"
    public let cancelButtonImageName = "b_storewindow_cancel.img"

    public private(set) var categoryButtons: [Button] = [
        Button(name: "b_store_buy.img"),
        Button(name: "b_store_cap.img"),
        Button(name: "b_store_cloth.img"),
        Button(name: "b_store_glasse.img"),
        Button(name: "b_store_flag.img"),
    ]

    public var cancelRect: Rect = .zero
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

    public func setRect(_ rect: Rect, forCategoryAt index: Int) {
        guard categoryButtons.indices.contains(index) else { return }
        categoryButtons[index].rect = rect
    }

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredIndex = categoryButtons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            if cancelRect.contains(x: x, y: y) {
                delegate.requestTransition(to: .gameRoomList)
            } else if let index = categoryButtons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) {
                print("[GunBound] clicked avatar-shop category: \(categoryButtons[index].name)")
            }

        case .activate:
            break
        }
    }
}
