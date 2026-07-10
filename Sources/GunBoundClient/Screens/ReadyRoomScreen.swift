import GunBound
import GunBoundProtocol
import GunBoundFile

/// View for the pre-battle Ready Room (state 9) — `ready_back.img` chrome
/// with the 8-slot roster (2×2 each side of the center map panel), the map
/// thumbnail, the character picker (a mode over the chat area, mobile
/// portraits from `ready_selectcharacter.img`), the room chat panel, and the
/// decomp-confirmed bottom bar (exit / buddy / change-team / ready-or-start —
/// the last swaps artwork by host status, as the original creates
/// `b_ready_startgame` for the host and `b_ready_ready` for guests in the
/// same slot). The live animated character/avatar preview is deferred with
/// the rest of the battle-render work.
@MainActor
public final class ReadyRoomScreen: GameScreen {
    private let viewModel: ReadyRoomViewModel
    private var backgroundTexture: ClientTexture?
    /// Map thumbnails (`ready_selectmap.img`, 22 frames) keyed by frame.
    private var mapThumbs: [Int: ClientTexture] = [:]
    /// Mobile portraits (`ready_selectcharacter.img`, 17 frames).
    private var characterFrames: [Int: ClientTexture] = [:]
    private var buttonTextures: [ReadyRoomViewModel.ButtonAction: ClientTexture] = [:]
    private var startTexture: ClientTexture?
    private var font: LoadedFont?
    private var rootWidget = Widget()
    private var chatPanel: LobbyChatWidget?
    private var buddyPanel: BuddyPanelWidget?
    private var audio: ClientAudioPlayer?

    /// Kept for lazily loading each roster mobile's animated tank sprite —
    /// the slots show the live mobile (idle `.epa` loop), not the picker card.
    private var assets: AssetLibrary?
    private var mobileAnimations: [Mobile: EpaFile] = [:]
    private var frameCache: [String: ClientTexture] = [:]
    /// Drives the slot mobiles' idle animation.
    private var clock: Double = 0

    public init(viewModel: ReadyRoomViewModel) {
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
        font = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        let mapCount = (try? assets.image(named: viewModel.mapThumbImageName).count) ?? 0
        for frame in 0..<mapCount {
            mapThumbs[frame] = renderer.texture(named: viewModel.mapThumbImageName, frame: frame, assets: assets)
        }
        let characterCount = (try? assets.image(named: viewModel.characterImageName).count) ?? 0
        for frame in 0..<characterCount {
            characterFrames[frame] = renderer.texture(named: viewModel.characterImageName, frame: frame, assets: assets)
        }

        buttonTextures[.exit] = renderer.texture(named: viewModel.exitButtonImageName, assets: assets)
        buttonTextures[.buddy] = renderer.texture(named: viewModel.buddyButtonImageName, assets: assets)
        buttonTextures[.changeTeam] = renderer.texture(named: viewModel.teamButtonImageName, assets: assets)
        buttonTextures[.readyOrStart] = renderer.texture(named: viewModel.readyButtonImageName, assets: assets)
        startTexture = renderer.texture(named: viewModel.startButtonImageName, assets: assets)

        // The room chat panel at the decomp rect (21,385) 480×160, scrollbar
        // (455,51) 18×69 page 9; the input line along the panel's bottom. The
        // scroll arrows sit *outside* the track — a gbview dump (panel 2000)
        // reports them at (476,408)/(476,515), i.e. panel-relative (455,23)/
        // (455,130) — not the track ends.
        rootWidget = Widget(frame: Rect(x: 0, y: 0, width: 800, height: 600))
        let chatPanel = LobbyChatWidget(
            frame: Rect(x: 21, y: 385, width: 480, height: 160),
            font: font,
            background: nil,  // the chat well is baked into ready_back.img
            inputFrame: Rect(x: 12, y: 140, width: 420, height: 12),
            scrollTrack: Rect(x: 455, y: 51, width: 18, height: 69),
            scrollKnobs: (
                up: Rect(x: 455, y: 23, width: 18, height: 18),
                down: Rect(x: 455, y: 130, width: 18, height: 18)
            ),
            visibleRows: 9
        )
        chatPanel.onSend = { [weak viewModel = self.viewModel] line in
            viewModel?.sendChat(line)
        }
        rootWidget.add(chatPanel)
        self.chatPanel = chatPanel

        // The shared buddy panel (the decomp's singleton, same as the
        // lobby's) — hidden until the BUDDY button toggles it.
        let buddyBack = renderer.texture(named: viewModel.buddyBackImageName, assets: assets)
        let (panelWidth, panelHeight) = renderer.size(of: buddyBack)
        let panelFrame = panelWidth > 0
            ? Rect(x: 568, y: 11, width: panelWidth, height: panelHeight)
            : BuddyPanelWidget.defaultFrame
        let buddyPanel = BuddyPanelWidget(
            frame: panelFrame,
            font: font,
            background: buddyBack,
            addTexture: renderer.texture(named: viewModel.buddyAddImageName, assets: assets),
            delTexture: renderer.texture(named: viewModel.buddyDelImageName, assets: assets),
            closeTexture: renderer.texture(named: viewModel.buddyCloseImageName, assets: assets),
            dialogBackground: renderer.texture(named: "buddy2.img", assets: assets),
            dialogAddTexture: renderer.texture(named: "b_buddy2_addfriend1.img", assets: assets),
            dialogCloseTexture: renderer.texture(named: "b_buddy2_close.img", assets: assets)
        )
        buddyPanel.isHidden = true
        buddyPanel.onClose = { [weak viewModel = self.viewModel] in viewModel?.dismissBuddyPanel() }
        buddyPanel.onAdd = { [weak viewModel = self.viewModel] name in viewModel?.addBuddy(named: name) }
        buddyPanel.onDelete = { [weak viewModel = self.viewModel] name in viewModel?.removeBuddy(named: name) }
        rootWidget.add(buddyPanel)
        self.buddyPanel = buddyPanel
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        mapThumbs = [:]
        characterFrames = [:]
        buttonTextures = [:]
        startTexture = nil
        font = nil
        rootWidget = Widget()
        chatPanel = nil
        buddyPanel = nil
        assets = nil
        mobileAnimations = [:]
        frameCache = [:]
        clock = 0
        audio?.stop()
        audio = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        // While the character picker is up it owns the chat region, so route
        // around the chat panel; otherwise widgets get first crack.
        if !viewModel.isPickerVisible, rootWidget.dispatch(event) {
            return
        }
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        clock += deltaTime
        audio?.update(deltaTime: deltaTime)
        viewModel.update(deltaTime: deltaTime)
        if let chatPanel {
            chatPanel.isHidden = viewModel.isPickerVisible
            if chatPanel.messages != viewModel.chatMessages {
                chatPanel.messages = viewModel.chatMessages
            }
        }
        if let buddyPanel {
            buddyPanel.isHidden = !viewModel.isBuddyPanelVisible
            buddyPanel.buddies = viewModel.buddies
        }
        rootWidget.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)

        // Map thumbnail in the center panel, picked by the room's map.
        let mapFrame = Int(viewModel.map.rawValue)
        if let thumb = mapThumbs[mapFrame] ?? mapThumbs[0] {
            renderer.draw(thumb, in: ReadyRoomViewModel.mapThumbRect, tint: nil)
        }

        if let font {
            // Room name in the top strip.
            font.draw(viewModel.roomName, x: 46, y: 12, using: renderer)
            font.draw("\(viewModel.map)", x: 580, y: 12, using: renderer)

            // Roster: name, team, and the live mobile per occupied slot —
            // the actual idle-animated tank sprite (as in battle), not the
            // picker's character card. Readied players are marked.
            for (index, player) in viewModel.players.enumerated() {
                let rect = viewModel.rosterSlotRect(at: index)
                let name = String(describing: player.username)
                font.draw(name, x: rect.x + 8, y: rect.y + 8, using: renderer)
                font.draw("Team \(player.team)", x: rect.x + 8, y: rect.y + 24, using: renderer)
                if let sprite = mobileSprite(for: player.primaryTank, renderer: renderer) {
                    let (w, h) = renderer.size(of: sprite)
                    // The tank frames are large; sit the mobile on the slot
                    // floor, centered, at its natural size (clamped to the slot).
                    let scale = min(1, (rect.height - 52) / max(1, h))
                    let dw = w * scale, dh = h * scale
                    renderer.draw(sprite, in: Rect(x: rect.x + (rect.width - dw) / 2, y: rect.y + rect.height - dh - 12, width: dw, height: dh), tint: nil)
                }
                if viewModel.readyPlayers.contains(name) {
                    font.draw("READY", x: rect.x + 8, y: rect.y + rect.height - 18, tint: (120, 255, 120), using: renderer)
                }
            }
        }

        // Bottom bar; the ready/start slot swaps artwork by host status.
        for (index, button) in viewModel.buttons.enumerated() {
            let texture: ClientTexture?
            if button.action == .readyOrStart {
                texture = viewModel.isHost ? startTexture : buttonTextures[.readyOrStart]
            } else {
                texture = buttonTextures[button.action]
            }
            guard let texture else { continue }
            var tint: (r: UInt8, g: UInt8, b: UInt8)? = index == viewModel.hoveredButtonIndex ? (200, 200, 255) : nil
            if button.action == .readyOrStart, viewModel.isReady {
                tint = (160, 255, 160)  // readied — green-lit
            }
            renderer.draw(texture, in: button.rect, tint: tint)
        }

        rootWidget.draw(renderer)

        // The character picker, over the chat area: the 5×3 grid of mobile
        // portraits (cell 13 dimmed — disabled in this build; the last cell
        // is random). The selected mobile's cell is highlighted.
        if viewModel.isPickerVisible, let font {
            for cell in 0..<ReadyRoomViewModel.pickerCellCount {
                let rect = ReadyRoomViewModel.pickerCellRect(at: cell)
                let isDisabled = cell == ReadyRoomViewModel.pickerDisabledCell
                let isRandom = cell == ReadyRoomViewModel.pickerCellCount - 1
                let mobile: Mobile? = isRandom ? .random : Mobile(rawValue: UInt8(cell))
                if !isRandom, let mobile,
                   let portrait = characterFrames[ReadyRoomViewModel.characterFrame(for: mobile)] {
                    let tint: (r: UInt8, g: UInt8, b: UInt8)? = isDisabled
                        ? (90, 90, 90)
                        : (mobile == viewModel.selectedMobile ? (255, 255, 160) : nil)
                    renderer.draw(portrait, in: rect, tint: tint)
                } else if isRandom {
                    font.draw("RANDOM", x: rect.x + 6, y: rect.y + 18, using: renderer)
                }
            }
        }
    }

    /// The current idle frame of a mobile's tank sprite — its `.epa` `normal`
    /// run looped by the screen clock, the same pipeline the battle uses.
    /// Loads the animation table lazily and caches decoded frames.
    private func mobileSprite(for mobile: Mobile, renderer: ClientRenderer) -> ClientTexture? {
        guard let assets else { return nil }
        if mobileAnimations[mobile] == nil {
            mobileAnimations[mobile] = try? assets.animationTable(named: mobile.tankAnimationName)
        }
        var frame = 0
        if let animation = mobileAnimations[mobile]?.animation(named: "normal") {
            frame = frameIndex(in: animation, age: clock)
        }
        let key = "\(mobile.tankImageName)#\(frame)"
        if let cached = frameCache[key] { return cached }
        let texture = renderer.texture(named: mobile.tankImageName, frame: frame, assets: assets)
        if let texture { frameCache[key] = texture }
        return texture
    }

    /// The looping frame index at `age` seconds, honoring the run's per-frame
    /// durations at ~15 ticks/s (matching the battle mobile animator).
    private func frameIndex(in animation: EpaFile.Animation, age: Double) -> Int {
        let total = max(1, animation.durations.reduce(0, +))
        let tick = max(0, Int(age * 15)) % total
        var elapsed = 0
        for (offset, duration) in animation.durations.enumerated() {
            elapsed += duration
            if tick < elapsed { return animation.frames[offset] }
        }
        return animation.frames.first ?? 0
    }
}
