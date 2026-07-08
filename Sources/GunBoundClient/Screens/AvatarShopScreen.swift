import CSDL3
import SDL3Swift
import GunBound

/// View for the Avatar Store / Shop (state 7) — all button routing/hover
/// logic lives in `AvatarShopViewModel`; this loads each category/cancel
/// button's texture and pushes the resulting hit-testing rects into the
/// view model.
@MainActor
final class AvatarShopScreen: GameScreen {
    private let viewModel: AvatarShopViewModel
    private let visuals = ScreenRenderHelper()
    private var categoryTextures: [SDLTexture?] = []
    private var cancelTexture: SDLTexture?

    init(viewModel: AvatarShopViewModel) {
        self.viewModel = viewModel
    }

    func onEnter(context: ScreenContext) throws {
        viewModel.onEnter()
        visuals.loadBackground(named: viewModel.backgroundImageName, context: context)

        var x: Float = 20
        let y: Float = 20
        categoryTextures = []
        for (index, button) in viewModel.categoryButtons.enumerated() {
            let texture = visuals.loadTexture(named: button.name, context: context)
            categoryTextures.append(texture)
            let (width, height) = size(of: texture)
            viewModel.setRect(Rect(x: x, y: y, width: width, height: height), forCategoryAt: index)
            x += width + 10
        }

        cancelTexture = visuals.loadTexture(named: viewModel.cancelButtonImageName, context: context)
        let (cancelWidth, cancelHeight) = size(of: cancelTexture)
        viewModel.cancelRect = Rect(x: 20, y: 600 - cancelHeight - 20, width: cancelWidth, height: cancelHeight)
    }

    func onExit() {
        viewModel.onExit()
        visuals.unloadBackground()
        categoryTextures = []
        cancelTexture = nil
    }

    func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        guard let input = translate(event) else { return }
        viewModel.handle(input)
    }

    func update(deltaTime: Double, context: ScreenContext) {
        viewModel.update(deltaTime: deltaTime)
    }

    func render(_ renderer: SDLRenderer) throws {
        try visuals.clearAndDrawBackground(renderer)
        for (index, button) in viewModel.categoryButtons.enumerated() {
            guard let texture = categoryTextures[index] else { continue }
            if index == viewModel.hoveredIndex {
                try texture.setColorModulation(red: 200, green: 200, blue: 255)
            } else {
                try texture.setColorModulation(red: 255, green: 255, blue: 255)
            }
            try renderer.copy(texture, destination: sdlRect(button.rect))
        }
        if let cancelTexture {
            try renderer.copy(cancelTexture, destination: sdlRect(viewModel.cancelRect))
        }
    }
}
