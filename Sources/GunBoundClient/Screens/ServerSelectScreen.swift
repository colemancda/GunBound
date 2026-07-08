import GunBound

/// View for Server / Channel select (state 2) — all connect/login logic
/// lives in `ServerSelectViewModel`; this loads/draws
/// `server_back.img`/`server_list.img`/the three confirmed button
/// images/`waitmessage.img`. Button rects come straight from the view
/// model (confirmed decomp positions, not computed here).
///
/// `panelRect`'s origin, (11,13), is visually confirmed (not
/// decomp-confirmed): `server_back.img` already contains a full "WORLD
/// LIST" panel baked in (empty/placeholder-character-art state), and
/// `server_list.img` is a second, same-sized (546x530) rendering of that
/// *same* panel in its populated-with-servers state — two states of one
/// panel meant to overlay exactly. (11,13) was found by comparing the two
/// extracted PNGs' border-region pixels (excluding the differing interior
/// artwork) across candidate offsets and taking the minimum pixel
/// difference — a clean, isolated best match (~34 avg channel diff vs. the
/// next-closest candidate's ~53), not just eyeballed.
@MainActor
public final class ServerSelectScreen: GameScreen {
    private let viewModel: ServerSelectViewModel
    private var backgroundTexture: ClientTexture?
    private var panelTexture: ClientTexture?
    private var buttonTextures: [ClientTexture?] = []
    private var waitTexture: ClientTexture?
    private var audio: ClientAudioPlayer?

    public init(viewModel: ServerSelectViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)
        if let musicName = viewModel.musicName {
            let audio = context.makeAudioPlayer()
            audio.play(named: musicName, assets: context.assets, loop: viewModel.loopMusic)
            self.audio = audio
        }

        panelTexture = context.renderer.texture(named: viewModel.panelImageName, assets: context.assets)
        let (panelWidth, panelHeight) = context.renderer.size(of: panelTexture)
        viewModel.panelRect = Rect(x: 11, y: 13, width: panelWidth, height: panelHeight)

        buttonTextures = viewModel.buttons.map { context.renderer.texture(named: $0.name, assets: context.assets) }

        waitTexture = context.renderer.texture(named: viewModel.waitImageName, assets: context.assets)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        panelTexture = nil
        buttonTextures = []
        waitTexture = nil
        audio?.stop()
        audio = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        audio?.update(deltaTime: deltaTime)
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)
        if let panelTexture {
            renderer.draw(panelTexture, in: viewModel.panelRect, tint: nil)
        }
        for (index, button) in viewModel.buttons.enumerated() {
            guard let texture = buttonTextures[index] else { continue }
            let tint: (r: UInt8, g: UInt8, b: UInt8)? = index == viewModel.hoveredIndex ? (200, 200, 255) : nil
            renderer.draw(texture, in: button.rect, tint: tint)
        }
        if viewModel.isConnecting, let waitTexture {
            let (width, height) = renderer.size(of: waitTexture)
            let rect = Rect(x: (800 - width) / 2, y: (600 - height) / 2, width: width, height: height)
            renderer.draw(waitTexture, in: rect, tint: nil)
        }
    }
}
