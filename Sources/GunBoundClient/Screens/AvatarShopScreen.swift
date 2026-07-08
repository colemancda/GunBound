import GunBound

/// View for the Avatar Store / Shop (state 7) — all button routing/hover
/// logic lives in `AvatarShopViewModel`; this loads each category/cancel
/// button's texture and pushes the resulting hit-testing rects into the
/// view model.
@MainActor
public final class AvatarShopScreen: GameScreen {
    private let viewModel: AvatarShopViewModel
    private var backgroundTexture: ClientTexture?
    private var categoryTextures: [ClientTexture?] = []
    private var cancelTexture: ClientTexture?
    /// Item icons loaded lazily by ID — the inventory arrives asynchronously,
    /// so item textures can't be preloaded in `onEnter`. `NSNull`-style: a
    /// cached `nil` marks "already tried, missing" so it isn't re-requested.
    private var itemTextures: [UInt32: ClientTexture?] = [:]
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
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)

        var x: Float = 20
        let y: Float = 20
        categoryTextures = []
        for (index, button) in viewModel.categoryButtons.enumerated() {
            let texture = context.renderer.texture(named: button.name, assets: context.assets)
            categoryTextures.append(texture)
            let (width, height) = context.renderer.size(of: texture)
            viewModel.setRect(Rect(x: x, y: y, width: width, height: height), forCategoryAt: index)
            x += width + 10
        }

        cancelTexture = context.renderer.texture(named: viewModel.cancelButtonImageName, assets: context.assets)
        let (cancelWidth, cancelHeight) = context.renderer.size(of: cancelTexture)
        viewModel.cancelRect = Rect(x: 20, y: 600 - cancelHeight - 20, width: cancelWidth, height: cancelHeight)

        font = LoadedFont(.numberFont, renderer: context.renderer, assets: context.assets)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        categoryTextures = []
        cancelTexture = nil
        itemTextures = [:]
        renderer = nil
        assets = nil
        font = nil
    }

    /// Loads (and caches) the icon for an item ID on demand — the inventory
    /// isn't known until the async fetch completes.
    private func itemTexture(for id: UInt32) -> ClientTexture? {
        if let cached = itemTextures[id] { return cached }
        guard let renderer, let assets else { return nil }
        let texture = renderer.texture(named: AvatarShopViewModel.itemSpriteName(for: id), assets: assets)
        itemTextures[id] = texture
        return texture
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)

        // Owned-item grid. This build's archives don't actually ship the
        // per-item `NNNNN.img` sprites (the "smaller private-server build"
        // pattern again), so when an icon is missing the item ID is drawn in
        // the bitmap number font instead of leaving an invisible cell.
        for (index, itemID) in viewModel.items.enumerated() {
            let rect = viewModel.itemRect(at: index)
            let selected = index == viewModel.selectedItemIndex
            if let texture = itemTexture(for: itemID) {
                renderer.draw(texture, in: rect, tint: selected ? (255, 240, 160) : nil)
            } else if let font {
                let text = "\(itemID)"
                font.draw(
                    text,
                    x: rect.x + (rect.width - font.width(of: text)) / 2,
                    y: rect.y + (rect.height - font.lineHeight) / 2,
                    using: renderer
                )
            }
        }

        for (index, button) in viewModel.categoryButtons.enumerated() {
            guard let texture = categoryTextures[index] else { continue }
            let tint: (r: UInt8, g: UInt8, b: UInt8)?
            if index == viewModel.selectedCategory {
                tint = (255, 255, 160)  // active tab
            } else if index == viewModel.hoveredIndex {
                tint = (200, 200, 255)  // hovered
            } else {
                tint = nil
            }
            renderer.draw(texture, in: button.rect, tint: tint)
        }
        if let cancelTexture {
            renderer.draw(cancelTexture, in: viewModel.cancelRect, tint: nil)
        }
    }
}
