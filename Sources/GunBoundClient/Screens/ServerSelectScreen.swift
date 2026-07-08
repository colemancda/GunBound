import GunBound

/// View for Server / Channel select (state 2) — all connect/login logic
/// lives in `ServerSelectViewModel`; this loads/draws
/// `server_back.img`/`server_list.img`/the three confirmed button
/// images/`waitmessage.img`, plus the WORLD LIST rows. Button and row rects
/// come straight from the view model (confirmed decomp positions/geometry,
/// not computed here).
///
/// `panelRect`'s origin, (11,13), was first found empirically (comparing the
/// two extracted PNGs' border-region pixels across candidate offsets) and
/// has since been decomp-confirmed: `BuildWorldListPanel` (`0x5099d0`)
/// creates the ~545×530 panel at exactly `(0xb, 0xd)`.
///
/// The world-list rows are drawn from `server_list.img`'s own frames — 1–4
/// are the row-background states (base/offline/connecting/highlighted) and
/// 5–9 the five population-gauge levels — matching the decompiled
/// `RenderWorldListRow` (`0x50dc80`): row background by selection state,
/// server number, name + description lines, and the population dial.
/// Server-side pagination (the scrollbar re-requesting pages via `0x1100`
/// with a scroll offset) isn't implemented: our broker returns a single
/// ≤16-entry page, which is all this build's fixed 16-slot storage holds.
@MainActor
public final class ServerSelectScreen: GameScreen {
    private let viewModel: ServerSelectViewModel
    private var backgroundTexture: ClientTexture?
    private var panelTexture: ClientTexture?
    private var buttonTextures: [ClientTexture?] = []
    private var waitTexture: ClientTexture?
    private var audio: ClientAudioPlayer?
    /// server_list.img frames 1–4: row background per state.
    private var rowBaseTexture: ClientTexture?
    private var rowOfflineTexture: ClientTexture?
    private var rowSelectedTexture: ClientTexture?
    /// server_list.img frames 5–9: the five population-gauge levels.
    private var gaugeTextures: [ClientTexture?] = []
    private var numberFont: LoadedFont?
    private var textFont: LoadedFont?

    public init(viewModel: ServerSelectViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets
        backgroundTexture = renderer.texture(named: viewModel.backgroundImageName, assets: assets)
        if let musicName = viewModel.musicName {
            let audio = context.makeAudioPlayer()
            audio.play(named: musicName, assets: assets, loop: viewModel.loopMusic)
            self.audio = audio
        }

        panelTexture = renderer.texture(named: viewModel.panelImageName, assets: assets)
        let (panelWidth, panelHeight) = renderer.size(of: panelTexture)
        viewModel.panelRect = Rect(x: 11, y: 13, width: panelWidth, height: panelHeight)

        // Row-state backgrounds and gauge levels live as frames of the same
        // sheet. Frame mapping (sprite "state" + 1, since frame 0 is the
        // panel): 1 = online base, 2 = offline, 4 = highlighted.
        rowBaseTexture = renderer.texture(named: viewModel.panelImageName, frame: 1, assets: assets)
        rowOfflineTexture = renderer.texture(named: viewModel.panelImageName, frame: 2, assets: assets)
        rowSelectedTexture = renderer.texture(named: viewModel.panelImageName, frame: 4, assets: assets)
        gaugeTextures = (5...9).map { renderer.texture(named: viewModel.panelImageName, frame: $0, assets: assets) }

        numberFont = LoadedFont(.numberFont, renderer: renderer, assets: assets)
        textFont = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        buttonTextures = viewModel.buttons.map { renderer.texture(named: $0.name, assets: assets) }

        waitTexture = renderer.texture(named: viewModel.waitImageName, assets: assets)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        panelTexture = nil
        buttonTextures = []
        waitTexture = nil
        rowBaseTexture = nil
        rowOfflineTexture = nil
        rowSelectedTexture = nil
        gaugeTextures = []
        numberFont = nil
        textFont = nil
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

        for (index, server) in viewModel.availableServers.enumerated() {
            let rect = viewModel.rowRect(at: index)

            // Row background by state.
            let background: ClientTexture?
            if index == viewModel.selectedIndex {
                background = rowSelectedTexture ?? rowBaseTexture
            } else if !server.isEnabled {
                background = rowOfflineTexture ?? rowBaseTexture
            } else {
                background = rowBaseTexture
            }
            if let background {
                renderer.draw(background, in: rect, tint: nil)
            }

            // Server number (the wire serverId + 1) in the row's title bar,
            // then name + up to two description lines below (the decomp's
            // y+0x1e origin with a 14px line pitch).
            numberFont?.draw("\(server.id + 1)", x: rect.x + 8, y: rect.y + 7, using: renderer)
            if let textFont {
                textFont.draw(server.name, x: rect.x + 30, y: rect.y + 6, using: renderer)
                let descriptionLines = server.descriptionText
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .prefix(2)
                for (line, text) in descriptionLines.enumerated() {
                    textFont.draw(
                        String(text).trimmingCharacters(in: .whitespaces),
                        x: rect.x + 10,
                        y: rect.y + 30 + Float(line) * 14,
                        using: renderer
                    )
                }
            }

            // Population gauge (F/E dial) beside the row.
            if let gauge = gaugeTextures[viewModel.populationLevel(of: server)] {
                renderer.draw(gauge, in: viewModel.gaugeRect(at: index), tint: nil)
            }
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
