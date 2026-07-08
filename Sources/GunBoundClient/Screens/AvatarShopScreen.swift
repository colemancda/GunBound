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

    public init(viewModel: AvatarShopViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
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
        for (index, button) in viewModel.categoryButtons.enumerated() {
            guard let texture = categoryTextures[index] else { continue }
            let tint: (r: UInt8, g: UInt8, b: UInt8)? = index == viewModel.hoveredIndex ? (200, 200, 255) : nil
            renderer.draw(texture, in: button.rect, tint: tint)
        }
        if let cancelTexture {
            renderer.draw(cancelTexture, in: viewModel.cancelRect, tint: nil)
        }
    }
}
