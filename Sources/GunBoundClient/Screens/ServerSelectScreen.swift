import GunBound
import GunBoundFile

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
    /// Per-button state artwork; the frame is chosen at draw time from each
    /// button's `ButtonState`.
    private var buttonSprites: [ButtonSprite] = []
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
    /// The shared buddy panel, hidden until the BUDDY button toggles it.
    private var buddyPanel: BuddyPanelWidget?
    /// The shared error popup (`error_back.img` + `b_error_confirm`), hidden
    /// until `viewModel.state` goes to `.error`.
    private var errorDialog: DialogWidget?
    /// Kept so the error dialog can resolve a `DialogMessage`'s localized-id
    /// text against `Language.txt` when it's shown.
    private var assets: AssetLibrary?

    /// A 1×1 opaque-white frame, stretched to fill the screen (tinted black
    /// at partial opacity) as the modal dialog's shade.
    private static let solidPixel = ImgFile.Frame(
        width: 1, height: 1,
        pixels: [ImgFile.Pixel(red: 255, green: 255, blue: 255, alpha: 255)]
    )

    public init(viewModel: ServerSelectViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets
        self.assets = assets
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
        // Track eyeballed; the knob hit-zones are measured from
        // server_list.img's baked round knobs (art y 43–66 / 458–481, +13
        // panel offset).
        let scrollBar = ScrollBarWidget(
            track: Rect(x: 522, y: 80, width: 32, height: 390),
            upArrow: Rect(x: 524, y: 56, width: 28, height: 24),
            downArrow: Rect(x: 524, y: 471, width: 28, height: 24)
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

        buttonSprites = viewModel.buttons.map { ButtonSprite(name: $0.name, renderer: renderer, assets: assets) }

        let waitFrameCount = (try? assets.image(named: viewModel.waitImageName).count) ?? 1
        waitFrames = (0..<waitFrameCount).map { renderer.texture(named: viewModel.waitImageName, frame: $0, assets: assets) }
        waitElapsed = 0

        // The shared buddy panel — hidden until the BUDDY button toggles it;
        // added before the error dialog so the dialog stays topmost.
        let buddyBack = renderer.texture(named: viewModel.buddyBackImageName, assets: assets)
        let buddyPanel = BuddyPanelWidget(
            font: textFont,
            background: buddyBack,
            addTexture: renderer.texture(named: viewModel.buddyAddImageName, assets: assets),
            delTexture: renderer.texture(named: viewModel.buddyDelImageName, assets: assets),
            closeTexture: renderer.texture(named: viewModel.buddyCloseImageName, assets: assets)
        )
        buddyPanel.isHidden = true
        buddyPanel.onClose = { [weak viewModel = self.viewModel] in viewModel?.dismissBuddyPanel() }
        rootWidget.add(buddyPanel)
        self.buddyPanel = buddyPanel

        // The shared error popup — added to the tree last so it sits topmost
        // and, once shown, its modal input handling shadows the scrollbar and
        // rows behind it.
        let errorBack = renderer.texture(named: viewModel.errorBackImageName, assets: assets)
        let (dialogWidth, dialogHeight) = renderer.size(of: errorBack)
        let dialogFrame = dialogWidth > 0
            ? Rect(x: (800 - dialogWidth) / 2, y: (600 - dialogHeight) / 2, width: dialogWidth, height: dialogHeight)
            : DialogWidget.defaultFrame
        let confirmTexture = renderer.texture(named: viewModel.errorConfirmImageName, assets: assets)
        let (confirmWidth, confirmHeight) = renderer.size(of: confirmTexture)
        // The OK button is right-aligned along the dialog's lower body,
        // matching the decomp's `b_error_confirm` at (0x1c6, 0x14b) — a ~25px
        // right margin, not centered.
        let confirmFrame = confirmWidth > 0
            ? Rect(x: dialogFrame.x + dialogFrame.width - confirmWidth - 25,
                   y: dialogFrame.y + dialogFrame.height - confirmHeight - 12,
                   width: confirmWidth, height: confirmHeight)
            : DialogWidget.defaultConfirmFrame
        let errorDialog = DialogWidget(
            frame: dialogFrame,
            font: textFont,
            background: errorBack,
            confirmFrame: confirmFrame,
            confirmTexture: confirmTexture
        )
        // A 1×1 opaque texture, stretched full-screen behind the panel for
        // the modal shade.
        errorDialog.dimTexture = renderer.texture(from: Self.solidPixel)
        errorDialog.isHidden = true
        errorDialog.onConfirm = { [weak viewModel = self.viewModel] in viewModel?.confirmError() }
        rootWidget.add(errorDialog)
        self.errorDialog = errorDialog
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        panelTexture = nil
        buttonSprites = []
        waitFrames = []
        waitElapsed = 0
        rowBaseTexture = nil
        rowOfflineTexture = nil
        rowSelectedTexture = nil
        gaugeTextures = []
        textFont = nil
        rootWidget = Widget()
        scrollBar = nil
        buddyPanel = nil
        errorDialog = nil
        assets = nil
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
        // Mirror the buddy-panel toggle and roster onto the widget.
        if let buddyPanel {
            buddyPanel.isHidden = !viewModel.isBuddyPanelVisible
            buddyPanel.buddies = viewModel.buddies
        }
        // Surface the view model's error state through the shared popup; hide
        // it again once the state clears (its OK button quits, like EXIT).
        if let errorDialog {
            if let message = viewModel.state.error {
                // Resolve the localized text (falling back to the built-in
                // string). The dialog puts its first line in the title strip
                // and the rest in the body, like the original.
                errorDialog.message = assets?.localizedString(message.localizedID) ?? message.fallback
                errorDialog.isHidden = false
            } else {
                errorDialog.isHidden = true
            }
        }
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
            // The SERVER button draws its `disabled` frame until a row is
            // selected — one click selects (enabling it), then the button or a
            // double-click on the row connects. Otherwise resolve
            // pressed/hovered/default from the pointer.
            let state: ButtonState
            if button.name == "b_server_choiceserver.img", !viewModel.isConnectEnabled {
                state = .disabled
            } else if index == viewModel.pressedIndex {
                state = .pressed
            } else if index == viewModel.hoveredIndex {
                state = .hovered
            } else {
                state = .normal
            }
            guard let texture = buttonSprites[index].texture(for: state) else { continue }
            renderer.draw(texture, in: button.rect, tint: nil)
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
