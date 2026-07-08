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
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        categoryTextures = []
        cancelTexture = nil
        itemTextures = [:]
        renderer = nil
        assets = nil
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

        // Owned-item grid.
        for (index, itemID) in viewModel.items.enumerated() {
            guard let texture = itemTexture(for: itemID) else { continue }
            let selected = index == viewModel.selectedItemIndex
            renderer.draw(texture, in: viewModel.itemRect(at: index), tint: selected ? (255, 240, 160) : nil)
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
