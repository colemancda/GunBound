import GunBoundProtocol

/// Logic for the Avatar Store / Shop (state 7) — reached from the Game Room
/// List's "Avatar" button.
///
/// The layout matches a live screenshot of the original: a 3×3 page of item
/// cards (`store_avatar.img` chrome) fills the big left panel, the four
/// category tabs (cap / cloth / glasses / flag → the Head / Body / Glasses /
/// Flag part tables, per `docs/screens/07_avatar_store.md`) sit bottom-left
/// with Try and Buy beside them, EXIT / BUDDY use the lobby's bottom-bar
/// convention, and the MY AVATAR panel (preview + inventory) fills the right
/// column.
///
/// The card catalog itself comes from `avatar.xfs`'s part tables (names,
/// gold/cash prices) — pushed in by the view via `setCatalog`, since file
/// parsing lives above this module. Try is the port of the store's
/// `PreviewAvatarPart` (`0x44b460`) — decomp-confirmed **local-only** (its
/// peers `EquipAvatarPart`/`UnequipAvatarSlot` are the ones that transmit):
/// it re-dresses the local preview and sends nothing. Buy needs the
/// `0x6017`/`0x6037` purchase round-trip and stays a follow-up.
@MainActor
public final class AvatarShopViewModel: ScreenViewModel {

    /// One purchasable part, as a card: an `avatar.xfs` catalog record's
    /// display fields plus what's needed to preview it.
    public struct ShopItem: Equatable, Sendable {
        /// The part id — its record index in the category's `.dat` table.
        public let id: Int
        public let name: String
        public let gold: Int32
        public let cash: Int32
        public let isMale: Bool

        public init(id: Int, name: String, gold: Int32, cash: Int32, isMale: Bool) {
            self.id = id
            self.name = name
            self.gold = gold
            self.cash = cash
            self.isMale = isMale
        }

        /// The part's equip code (bit 15 = gender, bits 0–14 = id).
        public var partCode: AvatarEquipment.Part {
            AvatarEquipment.Part(rawValue: UInt16(id & 0x7fff) | (isMale ? 0x8000 : 0))
        }
    }

    // MARK: Artwork

    public let backgroundImageName = "store_back.img"
    /// Card chrome sheet: frame 0 = card, 1 = selected card, 2 = BOY tag,
    /// 3 = GIRL tag, 4 = CASH label, 5 = GOLD label, 6/7 = CASH-/GOLD-ONLY,
    /// 8 = disabled cover.
    public let cardImageName = "store_avatar.img"
    /// The right column's inventory/EXITEM panel body.
    public let myAvatarImageName = "store_myavatar.img"
    public let tryButtonImageName = "b_store_puton.img"
    public let buyButtonImageName = "b_store_buy.img"
    public let exitButtonImageName = "b_store_exit.img"
    public let buddyButtonImageName = "b_store_buddygame.img"
    public let cashChargeImageName = "b_store_cashcharge.img"
    public let scrollUpImageName = "b_store_up.img"
    public let scrollDownImageName = "b_store_down.img"
    public let sellButtonImageName = "b_myavatar_sell.img"
    public let laundryButtonImageName = "b_myavatar_dry.img"
    public let giftButtonImageName = "b_myavatar_gift.img"

    /// The category tabs in on-screen order, with their 5-state artwork and
    /// the part table each one browses.
    public static let categoryTabs: [(name: String, category: AvatarEquipment.Category)] = [
        ("b_store_cap.img", .head),
        ("b_store_cloth.img", .body),
        ("b_store_glasse.img", .glasses),
        ("b_store_flag.img", .flag),
    ]

    // MARK: Geometry (screenshot-measured against the original)

    public static let cardColumns = 3
    public static let cardsPerPage = 9
    static let cardOrigin = (x: Float(22), y: Float(70))
    static let cardSize = (width: Float(160), height: Float(156))
    static let cardPitch = (x: Float(160), y: Float(161))

    /// On-screen rect of card `index` (0..<`cardsPerPage`, row-major).
    public static func cardRect(at index: Int) -> Rect {
        Rect(
            x: cardOrigin.x + Float(index % cardColumns) * cardPitch.x,
            y: cardOrigin.y + Float(index / cardColumns) * cardPitch.y,
            width: cardSize.width,
            height: cardSize.height
        )
    }

    /// The four category tabs along the bottom-left (49×32, 53 pitch).
    public static func categoryTabRect(at index: Int) -> Rect {
        Rect(x: 37 + Float(index) * 53, y: 561, width: 49, height: 32)
    }

    public static let tryRect = Rect(x: 357, y: 562, width: 81, height: 33)
    public static let buyRect = Rect(x: 447, y: 562, width: 81, height: 33)
    /// EXIT / BUDDY reuse the lobby bottom-bar convention (107×45 at y 551).
    public static let exitRect = Rect(x: 563, y: 551, width: 107, height: 45)
    public static let buddyRect = Rect(x: 678, y: 551, width: 107, height: 45)
    public static let cashChargeRect = Rect(x: 486, y: 6, width: 61, height: 40)
    /// The grid pager, in the panel's baked right-edge slots.
    public static let scrollUpRect = Rect(x: 517, y: 88, width: 16, height: 48)
    public static let scrollDownRect = Rect(x: 517, y: 480, width: 16, height: 48)
    /// The MY AVATAR preview box (top of the right column).
    public static let previewRect = Rect(x: 568, y: 40, width: 86, height: 64)
    /// The inventory/EXITEM panel body below it.
    public static let myAvatarPanelRect = Rect(x: 552, y: 108, width: 240, height: 437)
    public static let sellRect = Rect(x: 563, y: 519, width: 72, height: 29)
    public static let laundryRect = Rect(x: 637, y: 519, width: 72, height: 29)
    public static let giftRect = Rect(x: 711, y: 519, width: 72, height: 29)

    // MARK: State

    public private(set) var selectedCategory: AvatarEquipment.Category = .head
    public private(set) var page = 0
    /// Page-local index of the highlighted card, if any.
    public private(set) var selectedIndex: Int?
    public private(set) var hoveredTabIndex: Int?
    public private(set) var pressedTabIndex: Int?
    public private(set) var isLoading = false

    /// A local try-on override of the worn outfit (the original's preview
    /// context) — cleared when the fetched avatar changes underneath it.
    private var previewOverride: UInt64?

    private var catalogs: [AvatarEquipment.Category: [ShopItem]] = [:]

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    /// The outfit the MY AVATAR preview wears: the try-on override if one is
    /// active, else the fetched equipped outfit, else the standard male kit.
    public var previewEquipped: UInt64 {
        previewOverride ?? delegate.session.avatar?.equipped ?? Self.standardOutfit
    }

    /// All-male all-id-0 ("Standard") default when nothing is known.
    public static let standardOutfit: UInt64 = 0x8000_8000_8000_8000

    /// Owned item IDs for the inventory list.
    public var inventory: [UInt32] { delegate.session.avatar?.inventory ?? [] }

    /// The account name shown in the top info bar.
    public var username: String { delegate.network.username }

    /// The view pushes each category's parsed `avatar.xfs` catalog in here.
    public func setCatalog(_ items: [ShopItem], for category: AvatarEquipment.Category) {
        catalogs[category] = items
    }

    public func catalog(for category: AvatarEquipment.Category) -> [ShopItem] {
        catalogs[category] ?? []
    }

    /// The current page of the selected category's catalog (up to 9 cards).
    public var visibleItems: [ShopItem] {
        let items = catalog(for: selectedCategory)
        let start = page * Self.cardsPerPage
        guard start < items.count else { return [] }
        return Array(items[start..<min(start + Self.cardsPerPage, items.count)])
    }

    public var pageCount: Int {
        let count = catalog(for: selectedCategory).count
        return count == 0 ? 1 : (count + Self.cardsPerPage - 1) / Self.cardsPerPage
    }

    public var selectedItem: ShopItem? {
        guard let selectedIndex else { return nil }
        let items = visibleItems
        return items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }

    public func onEnter() {
        selectedIndex = nil
        previewOverride = nil
        page = 0
        loadInventory()
    }

    public func onExit() {
        hoveredTabIndex = nil
        pressedTabIndex = nil
    }

    public func update(deltaTime: Double) {}

    // MARK: Actions

    private func select(category: AvatarEquipment.Category) {
        guard category != selectedCategory else { return }
        selectedCategory = category
        page = 0
        selectedIndex = nil
    }

    private func turnPage(_ delta: Int) {
        let next = page + delta
        guard next >= 0, next < pageCount else { return }
        page = next
        selectedIndex = nil
    }

    /// Try: re-dress the local preview with the selected part (the decomp's
    /// slot handler pushes the code into the store context and re-runs the
    /// compositor — no server round-trip).
    private func tryOnSelected() {
        guard let item = selectedItem else { return }
        previewOverride = AvatarEquipment(rawValue: previewEquipped)
            .equipping(item.partCode, in: selectedCategory)
            .rawValue
    }

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredTabIndex = (0..<Self.categoryTabs.count)
                .first { Self.categoryTabRect(at: $0).contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            if let tab = (0..<Self.categoryTabs.count).first(where: { Self.categoryTabRect(at: $0).contains(x: x, y: y) }) {
                pressedTabIndex = tab
                select(category: Self.categoryTabs[tab].category)
            } else if Self.exitRect.contains(x: x, y: y) {
                delegate.requestTransition(to: .gameRoomList)
            } else if Self.tryRect.contains(x: x, y: y) {
                tryOnSelected()
            } else if Self.buyRect.contains(x: x, y: y) {
                // Purchase needs the 0x6017 confirm → 0x6037 commit round-trip.
                print("[GunBound] avatar-shop buy: \(selectedItem?.name ?? "no selection")")
            } else if Self.scrollUpRect.contains(x: x, y: y) {
                turnPage(-1)
            } else if Self.scrollDownRect.contains(x: x, y: y) {
                turnPage(1)
            } else if let card = (0..<visibleItems.count).first(where: { Self.cardRect(at: $0).contains(x: x, y: y) }) {
                selectedIndex = card
            }

        case .pointerUp:
            pressedTabIndex = nil

        case .scroll(_, _, let steps):
            turnPage(steps > 0 ? -1 : 1)

        case .activate, .text, .key:
            break
        }
    }

    /// Fetches the player's avatar/inventory (opcode `0x6000`) into the
    /// session so the preview and inventory list reflect the account.
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
