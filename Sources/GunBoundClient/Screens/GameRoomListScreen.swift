import GunBound

/// View for the Game Room List / channel lobby (state 3) — all button
/// routing/hover logic lives in `GameRoomListViewModel`; this loads each
/// button's texture, lays them out left-to-right, and pushes the resulting
/// hit-testing rects into the view model.
@MainActor
public final class GameRoomListScreen: GameScreen {
    private let viewModel: GameRoomListViewModel
    private var backgroundTexture: ClientTexture?
    private var buttonTextures: [ClientTexture?] = []

    public init(viewModel: GameRoomListViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)

        var x: Float = 20
        let y: Float = 540
        buttonTextures = []
        for (index, button) in viewModel.buttons.enumerated() {
            let texture = context.renderer.texture(named: button.name, assets: context.assets)
            buttonTextures.append(texture)
            let (width, height) = context.renderer.size(of: texture)
            viewModel.setRect(Rect(x: x, y: y, width: width, height: height), forButtonAt: index)
            x += width + 10
        }
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        buttonTextures = []
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
        for (index, button) in viewModel.buttons.enumerated() {
            guard let texture = buttonTextures[index] else { continue }
            let tint: (r: UInt8, g: UInt8, b: UInt8)? = index == viewModel.hoveredIndex ? (200, 200, 255) : nil
            renderer.draw(texture, in: button.rect, tint: tint)
        }
    }
}
