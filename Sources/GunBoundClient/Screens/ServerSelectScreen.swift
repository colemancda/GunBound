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
    /// `waitmessage.img`'s four animation frames, cycled while the world
    /// list is loading or a connect attempt is in flight.
    private var waitFrames: [ClientTexture?] = []
    private var waitElapsed: Double = 0
    private var audio: ClientAudioPlayer?
    /// server_list.img frames 1–4: row background per state.
    private var rowBaseTexture: ClientTexture?
    private var rowOfflineTexture: ClientTexture?
    private var rowSelectedTexture: ClientTexture?
    /// server_list.img frames 5–9: the five population-gauge levels.
    private var gaugeTextures: [ClientTexture?] = []
    private var textFont: LoadedFont?
    /// Widget tree root — currently just the panel's scrollbar (invisible
    /// arrow hit-zones over the knobs baked into the panel chrome), stepping
    /// the world-list scroll window when more than 12 servers are fetched.
    private var rootWidget = Widget()
    private var scrollBar: ScrollBarWidget?

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

        // The panel's scroll track (arrow knobs are baked into the chrome at
        // the track's ends — eyeballed positions, not decomp-recorded); the
        // widget supplies the missing interactivity.
        rootWidget = Widget(frame: Rect(x: 0, y: 0, width: 800, height: 600))
        let scrollBar = ScrollBarWidget(
            track: Rect(x: 522, y: 48, width: 32, height: 480),
            arrowSize: 32
        )
        scrollBar.pageSize = ServerSelectViewModel.maxVisibleRows / ServerSelectViewModel.rowColumns
        scrollBar.onScroll = { [weak viewModel = self.viewModel] position in
            viewModel?.setScrollOffset(position)
        }
        rootWidget.add(scrollBar)
        self.scrollBar = scrollBar

        // Row-state backgrounds and gauge levels live as frames of the same
        // sheet. Frame mapping confirmed by extracting the frames: 1 = base
        // (dark title bar, matches the original's normal rows), 2 = the
        // slightly-brighter connecting state, 3 = brightest (highlighted),
        // 4 = gray (offline/disabled).
        rowBaseTexture = renderer.texture(named: viewModel.panelImageName, frame: 1, assets: assets)
        rowSelectedTexture = renderer.texture(named: viewModel.panelImageName, frame: 3, assets: assets)
        rowOfflineTexture = renderer.texture(named: viewModel.panelImageName, frame: 4, assets: assets)
        gaugeTextures = (5...9).map { renderer.texture(named: viewModel.panelImageName, frame: $0, assets: assets) }

        textFont = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        buttonTextures = viewModel.buttons.map { renderer.texture(named: $0.name, assets: assets) }

        let waitFrameCount = (try? assets.image(named: viewModel.waitImageName).count) ?? 1
        waitFrames = (0..<waitFrameCount).map { renderer.texture(named: viewModel.waitImageName, frame: $0, assets: assets) }
        waitElapsed = 0
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        panelTexture = nil
        buttonTextures = []
        waitFrames = []
        waitElapsed = 0
        rowBaseTexture = nil
        rowOfflineTexture = nil
        rowSelectedTexture = nil
        gaugeTextures = []
        textFont = nil
        rootWidget = Widget()
        scrollBar = nil
        audio?.stop()
        audio = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        if rootWidget.dispatch(event) {
            return
        }
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        audio?.update(deltaTime: deltaTime)
        viewModel.update(deltaTime: deltaTime)
        scrollBar?.contentCount = viewModel.lineCount
        rootWidget.update(deltaTime: deltaTime)
        // Advance the wait-message animation while busy; restart it from
        // frame 0 the next time it appears.
        if viewModel.state.isLoading || viewModel.state.isConnecting {
            waitElapsed += deltaTime
        } else {
            waitElapsed = 0
        }
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)
        if let panelTexture {
            renderer.draw(panelTexture, in: viewModel.panelRect, tint: nil)
        }

        // Pale cyan for descriptions — the decomp's flat RGB565 text color
        // 0xb77f expanded to 8-bit channels.
        let descriptionTint: (r: UInt8, g: UInt8, b: UInt8) = (181, 239, 255)

        for (index, server) in viewModel.visibleServers.enumerated() {
            let rect = viewModel.rowRect(at: index)

            // Row background by state.
            let background: ClientTexture?
            if viewModel.absoluteIndex(forVisibleSlot: index) == viewModel.selectedIndex {
                background = rowSelectedTexture ?? rowBaseTexture
            } else if !server.isEnabled {
                background = rowOfflineTexture ?? rowBaseTexture
            } else {
                background = rowBaseTexture
            }
            if let background {
                renderer.draw(background, in: rect, tint: nil)
            }

            // Title bar (spans y+5…y+24 in the frame): the server number
            // (the wire serverId + 1, white like the original) at x+10, the
            // name at x+32, both vertically centered at y+8. Description
            // lines fill the body band — the decomp's y+0x1e origin with a
            // 14px line pitch — in the original's pale cyan.
            if let textFont {
                textFont.draw("\(server.id + 1)", x: rect.x + 10, y: rect.y + 8, using: renderer)
                textFont.draw(server.name, x: rect.x + 32, y: rect.y + 8, using: renderer)
                let descriptionLines = server.descriptionText
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .prefix(2)
                for (line, text) in descriptionLines.enumerated() {
                    textFont.draw(
                        String(text).trimmingCharacters(in: .whitespaces),
                        x: rect.x + 12,
                        y: rect.y + 30 + Float(line) * 14,
                        tint: descriptionTint,
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
        rootWidget.draw(renderer)

        // Animated "please wait" overlay — shown while fetching the world
        // list as well as while a connect attempt is in flight, cycling
        // waitmessage.img's four frames.
        if viewModel.state.isLoading || viewModel.state.isConnecting, !waitFrames.isEmpty {
            let frameIndex = Int(waitElapsed / 0.15) % waitFrames.count
            if let frame = waitFrames[frameIndex] {
                let (width, height) = renderer.size(of: frame)
                let rect = Rect(x: (800 - width) / 2, y: (600 - height) / 2, width: width, height: height)
                renderer.draw(frame, in: rect, tint: nil)
            }
        }
    }
}
