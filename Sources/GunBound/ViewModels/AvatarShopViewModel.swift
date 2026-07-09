import GunBoundProtocol

/// Logic for the Avatar Store / Shop (state 7) — reached from the Game Room
/// List's "Avatar" button. Fetches the player's avatar/inventory on entry
/// (opcode `0x6000` → `0x6001`) and lays out the owned items in a grid, plus
/// the category tabs and cancel control.
///
/// Item sprites are named by zero-padded item ID (`NNNNN.img`, per
/// `FILEFORMATS.md`). Category filtering (which tab shows which items) and the
/// buy → confirm → commit purchase flow (`0x6017`/`0x6037`) are left as
/// follow-ups: they need the item→category/price data from `itemdata.dat` and
/// the multi-step purchase dialogs.
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

    // MARK: Item grid geometry
    public static let itemColumns = 5
    public static let maxVisibleItems = 20
    static let itemOrigin = (x: Float(210), y: Float(120))
    static let itemCellSize = (width: Float(64), height: Float(64))
    static let itemSpacing = (x: Float(6), y: Float(6))

    public var cancelRect: Rect = .zero
    public private(set) var hoveredIndex: Int?
    public private(set) var selectedCategory = 0
    public private(set) var selectedItemIndex: Int?
    public private(set) var isLoading = false

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    /// Owned item IDs from the fetched avatar (capped to the visible grid).
    public var items: [UInt32] {
        Array((delegate.session.avatar?.inventory ?? []).prefix(Self.maxVisibleItems))
    }

    /// The `.img` sprite name for an item ID — zero-padded to five digits.
    public static func itemSpriteName(for id: UInt32) -> String {
        var digits = "\(id)"
        while digits.count < 5 { digits = "0" + digits }
        return digits + ".img"
    }

    /// On-screen rect of item slot `index` (row-major, `itemColumns` wide).
    public func itemRect(at index: Int) -> Rect {
        let column = index % Self.itemColumns
        let row = index / Self.itemColumns
        return Rect(
            x: Self.itemOrigin.x + Float(column) * (Self.itemCellSize.width + Self.itemSpacing.x),
            y: Self.itemOrigin.y + Float(row) * (Self.itemCellSize.height + Self.itemSpacing.y),
            width: Self.itemCellSize.width,
            height: Self.itemCellSize.height
        )
    }

    public func onEnter() {
        hoveredIndex = nil
        selectedItemIndex = nil
        loadInventory()
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
                selectedCategory = index
                print("[GunBound] avatar-shop category: \(categoryButtons[index].name)")
            } else if let itemIndex = (0..<items.count).first(where: { itemRect(at: $0).contains(x: x, y: y) }) {
                selectedItemIndex = itemIndex
            }

        case .pointerUp, .activate, .text, .key, .scroll:
            break
        }
    }

    /// Fetches the player's avatar/inventory (opcode `0x6000`) into the
    /// session so the grid can display owned items.
    private func loadInventory() {
        guard delegate.session.avatar == nil, let client = delegate.client else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let avatar = try await client.fetchAvatar()
                delegate.session.avatar = avatar
                print("[GunBound] avatar inventory: \(avatar.inventory.count) item(s)")
            } catch {
                print("[GunBound] couldn't fetch avatar: \(error)")
            }
        }
    }
}
