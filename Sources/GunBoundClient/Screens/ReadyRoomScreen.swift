import GunBound

/// View for the pre-battle Ready Room (state 9). Loads the map/character
/// select chrome and the start/cancel buttons, and draws the 8-slot roster
/// (player names + team, from the session's joined room) plus the room name
/// and selected map using the bitmap font. The live 3D character preview the
/// original draws is deferred with the rest of the battle-render work.
@MainActor
public final class ReadyRoomScreen: GameScreen {
    private let viewModel: ReadyRoomViewModel
    private var backgroundTexture: ClientTexture?
    private var characterSelectTexture: ClientTexture?
    private var startTexture: ClientTexture?
    private var cancelTexture: ClientTexture?
    private var font: LoadedFont?

    public init(viewModel: ReadyRoomViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets
        backgroundTexture = renderer.texture(named: viewModel.backgroundImageName, assets: assets)
        characterSelectTexture = renderer.texture(named: viewModel.characterSelectImageName, assets: assets)
        font = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        startTexture = renderer.texture(named: viewModel.startButtonImageName, assets: assets)
        let (startWidth, startHeight) = renderer.size(of: startTexture)
        viewModel.startRect = Rect(x: 800 - startWidth - 20, y: 600 - startHeight - 20, width: startWidth, height: startHeight)

        cancelTexture = renderer.texture(named: viewModel.cancelButtonImageName, assets: assets)
        let (cancelWidth, cancelHeight) = renderer.size(of: cancelTexture)
        viewModel.cancelRect = Rect(x: 20, y: 600 - cancelHeight - 20, width: cancelWidth, height: cancelHeight)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        characterSelectTexture = nil
        startTexture = nil
        cancelTexture = nil
        font = nil
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
        drawFullSize(characterSelectTexture, using: renderer)

        if let font {
            // Room name + map along the top.
            font.draw("\(viewModel.roomName)  -  \(viewModel.map)", x: 40, y: 40, using: renderer)

            // Roster slots: each occupied slot shows the player's name and team.
            for (index, player) in viewModel.players.enumerated() {
                let rect = viewModel.rosterSlotRect(at: index)
                font.draw("\(player.username)", x: rect.x + 6, y: rect.y + 6, using: renderer)
                font.draw("Team \(player.team)", x: rect.x + 6, y: rect.y + 22, using: renderer)
            }
        }

        if let startTexture {
            let tint: (r: UInt8, g: UInt8, b: UInt8)? = viewModel.isReady ? (160, 255, 160) : nil
            renderer.draw(startTexture, in: viewModel.startRect, tint: tint)
        }
        if let cancelTexture {
            renderer.draw(cancelTexture, in: viewModel.cancelRect, tint: nil)
        }
    }
}
