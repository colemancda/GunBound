import GunBound
import GunBoundProtocol

/// View for the Avatar Store / Shop (state 7) — `store_back.img` chrome with
/// the 3×3 page of item cards (`store_avatar.img`), the four category tabs +
/// Try/Buy along the bottom, EXIT/BUDDY in the lobby's bottom-bar convention,
/// and the MY AVATAR column (live composited preview over `store_myavatar.img`).
///
/// The catalog on the cards is loaded straight from `avatar.xfs`'s part
/// tables (male catalogs; names + gold/cash prices) and pushed into the view
/// model; each card's icon is the part's large (`…l.img`) sprite. Per-part
/// stat icons (`store_icon.img`) need the stat→icon mapping and are deferred.
@MainActor
public final class AvatarShopScreen: GameScreen {
    private let viewModel: AvatarShopViewModel
    private var backgroundTexture: ClientTexture?
    private var myAvatarTexture: ClientTexture?
    /// `store_avatar.img` frames (card, selected, BOY/GIRL, CASH/GOLD...).
    private var cardFrames: [Int: ClientTexture] = [:]
    private var categorySprites: [ButtonSprite] = []
    private var actionSprites: [String: ButtonSprite] = [:]
    /// Large part sprites by entry name; `nil` cached for missing art.
    private var iconTextures: [String: ClientTexture?] = [:]
    private let avatarCache = AvatarSpriteCache()
    private weak var renderer: ClientRenderer?
    private var assets: AssetLibrary?
    private var font: LoadedFont?

    public init(viewModel: AvatarShopViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        renderer = context.renderer
        assets = context.assets
        let renderer = context.renderer
        let assets = context.assets

        backgroundTexture = renderer.texture(named: viewModel.backgroundImageName, assets: assets)
        myAvatarTexture = renderer.texture(named: viewModel.myAvatarImageName, assets: assets)
        for frame in 0..<9 {
            cardFrames[frame] = renderer.texture(named: viewModel.cardImageName, frame: frame, assets: assets)
        }

        categorySprites = AvatarShopViewModel.categoryTabs.map {
            ButtonSprite(name: $0.name, renderer: renderer, assets: assets)
        }
        for name in [
            viewModel.tryButtonImageName, viewModel.buyButtonImageName,
            viewModel.exitButtonImageName, viewModel.buddyButtonImageName,
            viewModel.cashChargeImageName,
            viewModel.scrollUpImageName, viewModel.scrollDownImageName,
            viewModel.sellButtonImageName, viewModel.laundryButtonImageName,
            viewModel.giftButtonImageName,
        ] {
            actionSprites[name] = ButtonSprite(name: name, renderer: renderer, assets: assets)
        }

        font = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        // The card catalog comes from avatar.xfs's part tables (male
        // catalogs; flags are gender-neutral and live in mf.dat), only the
        // purchasable records.
        for (_, category) in AvatarShopViewModel.categoryTabs {
            let table = "m\(category.code).dat"
            let items = (try? assets.avatarCatalog(named: table)) ?? []
            viewModel.setCatalog(
                items.filter(\.buyable).map {
                    AvatarShopViewModel.ShopItem(
                        id: Int($0.index),
                        name: $0.name,
                        gold: $0.gold,
                        cash: $0.cash,
                        isMale: true
                    )
                },
                for: category
            )
        }
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        myAvatarTexture = nil
        cardFrames = [:]
        categorySprites = []
        actionSprites = [:]
        iconTextures = [:]
        avatarCache.reset()
        renderer = nil
        assets = nil
        font = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        viewModel.update(deltaTime: deltaTime)
    }

    /// A part's large in-store icon (`{g}{cat}{id:05}l.img`), cached by name.
    private func icon(for item: AvatarShopViewModel.ShopItem) -> ClientTexture? {
        let equipment = AvatarEquipment(rawValue: 0).equipping(item.partCode, in: viewModel.selectedCategory)
        guard let name = equipment.spriteName(viewModel.selectedCategory, large: true) else { return nil }
        if let cached = iconTextures[name] { return cached }
        guard let renderer, let assets else { return nil }
        let texture = renderer.texture(named: name, assets: assets)
        iconTextures[name] = texture
        return texture
    }

    /// `12345` → `"12,345"` for the price lines.
    static func priceText(_ value: Int32) -> String {
        var digits = String(max(0, value)), grouped = ""
        while digits.count > 3 {
            grouped = "," + digits.suffix(3) + grouped
            digits = String(digits.dropLast(3))
        }
        return digits + grouped
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)

        // The right column's inventory/EXITEM panel body.
        if let myAvatarTexture {
            renderer.draw(myAvatarTexture, in: AvatarShopViewModel.myAvatarPanelRect, tint: nil)
        }

        // The item cards: chrome, name, gender tag, large part icon, prices.
        for (index, item) in viewModel.visibleItems.enumerated() {
            let rect = AvatarShopViewModel.cardRect(at: index)
            let selected = index == viewModel.selectedIndex
            if let card = cardFrames[0] {
                renderer.draw(card, in: rect, tint: selected ? (255, 235, 170) : nil)
            }
            if let font {
                font.draw(item.name, x: rect.x + 10, y: rect.y + 6, using: renderer)
            }
            if let tag = cardFrames[item.isMale ? 2 : 3] {
                let (w, h) = renderer.size(of: tag)
                renderer.draw(tag, in: Rect(x: rect.x + rect.width - w - 8, y: rect.y + 5, width: w, height: h), tint: nil)
            }
            if let icon = icon(for: item) {
                // Centered in the card's white icon box, at natural size
                // (clamped to the box).
                let box = Rect(x: rect.x + 6, y: rect.y + 26, width: 86, height: 70)
                let (w, h) = renderer.size(of: icon)
                let scale = min(1, min(box.width / max(1, w), box.height / max(1, h)))
                let dw = w * scale, dh = h * scale
                renderer.draw(icon, in: Rect(x: box.x + (box.width - dw) / 2, y: box.y + (box.height - dh) / 2, width: dw, height: dh), tint: nil)
            }
            drawPrice(item.cash, label: cardFrames[4], tint: (255, 232, 90), atY: rect.y + 112, in: rect, using: renderer)
            drawPrice(item.gold, label: cardFrames[5], tint: (140, 255, 150), atY: rect.y + 131, in: rect, using: renderer)
        }

        // Category tabs (selected/pressed/hovered frames) + action buttons.
        for (index, _) in AvatarShopViewModel.categoryTabs.enumerated() {
            let state: ButtonState
            if AvatarShopViewModel.categoryTabs[index].category == viewModel.selectedCategory {
                state = .selected
            } else if index == viewModel.pressedTabIndex {
                state = .pressed
            } else if index == viewModel.hoveredTabIndex {
                state = .hovered
            } else {
                state = .normal
            }
            if let texture = categorySprites[index].texture(for: state) {
                renderer.draw(texture, in: AvatarShopViewModel.categoryTabRect(at: index), tint: nil)
            }
        }
        drawAction(viewModel.tryButtonImageName, in: AvatarShopViewModel.tryRect, using: renderer)
        drawAction(viewModel.buyButtonImageName, in: AvatarShopViewModel.buyRect, using: renderer)
        drawAction(viewModel.exitButtonImageName, in: AvatarShopViewModel.exitRect, using: renderer)
        drawAction(viewModel.buddyButtonImageName, in: AvatarShopViewModel.buddyRect, using: renderer)
        drawAction(viewModel.cashChargeImageName, in: AvatarShopViewModel.cashChargeRect, using: renderer)
        drawAction(viewModel.scrollUpImageName, in: AvatarShopViewModel.scrollUpRect, using: renderer)
        drawAction(viewModel.scrollDownImageName, in: AvatarShopViewModel.scrollDownRect, using: renderer)
        drawAction(viewModel.sellButtonImageName, in: AvatarShopViewModel.sellRect, using: renderer)
        drawAction(viewModel.laundryButtonImageName, in: AvatarShopViewModel.laundryRect, using: renderer)
        drawAction(viewModel.giftButtonImageName, in: AvatarShopViewModel.giftRect, using: renderer)

        // The live MY AVATAR preview — the composited worn (or tried-on)
        // outfit, centered in the preview box.
        if let assets,
           let avatar = avatarCache.sprite(equipped: viewModel.previewEquipped, assets: assets, renderer: renderer) {
            let box = AvatarShopViewModel.previewRect
            let (w, h) = renderer.size(of: avatar)
            let scale = min(1, min(box.width / max(1, w), box.height / max(1, h)))
            let dw = w * scale, dh = h * scale
            renderer.draw(avatar, in: Rect(x: box.x + (box.width - dw) / 2, y: box.y + (box.height - dh) / 2, width: dw, height: dh), tint: nil)
        }

        // Owned-item IDs down the inventory rows until the id→name mapping
        // is decoded.
        if let font {
            for (row, id) in viewModel.inventory.prefix(11).enumerated() {
                font.draw("\(id)", x: AvatarShopViewModel.myAvatarPanelRect.x + 18, y: AvatarShopViewModel.myAvatarPanelRect.y + 10 + Float(row) * 19, using: renderer)
            }
            // The account line in the top info bar.
            font.draw(viewModel.username, x: 196, y: 12, using: renderer)
        }
    }

    /// One price line: the amount right-aligned before its CASH/GOLD label
    /// art, the pair centered in the card.
    private func drawPrice(
        _ value: Int32,
        label: ClientTexture?,
        tint: (r: UInt8, g: UInt8, b: UInt8),
        atY y: Float,
        in card: Rect,
        using renderer: ClientRenderer
    ) {
        guard let font else { return }
        let text = Self.priceText(value)
        let textWidth = font.width(of: text)
        var labelWidth: Float = 0
        var labelHeight: Float = 0
        if let label {
            (labelWidth, labelHeight) = renderer.size(of: label)
        }
        let total = textWidth + 5 + labelWidth
        let x = card.x + (card.width - total) / 2
        font.draw(text, x: x, y: y, tint: tint, using: renderer)
        if let label {
            renderer.draw(label, in: Rect(x: x + textWidth + 5, y: y + (font.lineHeight - labelHeight) / 2, width: labelWidth, height: labelHeight), tint: nil)
        }
    }

    private func drawAction(_ name: String, in rect: Rect, using renderer: ClientRenderer) {
        guard let texture = actionSprites[name]?.texture(for: .normal) else { return }
        renderer.draw(texture, in: rect, tint: nil)
    }
}
