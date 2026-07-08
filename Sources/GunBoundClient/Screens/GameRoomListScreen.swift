import CSDL3
import SDL3Swift
import GunBound

/// View for the Game Room List / channel lobby (state 3) — all button
/// routing/hover logic lives in `GameRoomListViewModel`; this loads each
/// button's texture, lays them out left-to-right, and pushes the resulting
/// hit-testing rects into the view model.
@MainActor
final class GameRoomListScreen: GameScreen {
    private let viewModel: GameRoomListViewModel
    private let visuals = ScreenRenderHelper()
    private var buttonTextures: [SDLTexture?] = []

    init(viewModel: GameRoomListViewModel) {
        self.viewModel = viewModel
    }

    func onEnter(context: ScreenContext) throws {
        viewModel.onEnter()
        visuals.loadBackground(named: viewModel.backgroundImageName, context: context)

        var x: Float = 20
        let y: Float = 540
        buttonTextures = []
        for (index, button) in viewModel.buttons.enumerated() {
            let texture = visuals.loadTexture(named: button.name, context: context)
            buttonTextures.append(texture)
            let (width, height) = size(of: texture)
            viewModel.setRect(Rect(x: x, y: y, width: width, height: height), forButtonAt: index)
            x += width + 10
        }
    }

    func onExit() {
        viewModel.onExit()
        visuals.unloadBackground()
        buttonTextures = []
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
        for (index, button) in viewModel.buttons.enumerated() {
            guard let texture = buttonTextures[index] else { continue }
            if index == viewModel.hoveredIndex {
                try texture.setColorModulation(red: 200, green: 200, blue: 255)
            } else {
                try texture.setColorModulation(red: 255, green: 255, blue: 255)
            }
            try renderer.copy(texture, destination: sdlRect(button.rect))
        }
    }
}
