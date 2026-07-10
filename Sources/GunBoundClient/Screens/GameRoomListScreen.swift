import GunBound

/// View for the Game Room List / channel lobby (state 3) — all routing,
/// room-list networking, and hit-testing live in `GameRoomListViewModel`;
/// this loads the chrome/button/room-card textures and draws them at the
/// rects the view model computes.
///
/// The room cards, their highlighted state, and the waiting/playing/full
/// status icons are all separate frames inside `gamelist_back.img` (frames
/// 1–3 = card base / highlighted / joined; frames 7–9 = status icons), per
/// the decompiled `RenderRoomLabel` (`docs/screens/03_game_room_list.md`).
/// Per-card text (room number, `[players/max]` count) needs a bitmap-font
/// path this client doesn't have yet, so cards render as the sheet's own art
/// plus the status icon — a follow-up can add the text overlay.
@MainActor
public final class GameRoomListScreen: GameScreen {
    private let viewModel: GameRoomListViewModel
    private var backgroundTexture: ClientTexture?
    /// Per-button state artwork; the correct frame is chosen at draw time from
    /// the button's `ButtonState` (default/hovered/pressed/disabled/selected).
    private var buttonSprites: [ButtonSprite] = []
    /// `gamelist_back.img` frames keyed by frame index (see `RenderRoomCard`):
    /// 1–6 card backgrounds, 7–9 status icons, 10–13 game-mode labels, 15
    /// padlock. Stored sparse by index so drawing reads them by the frame
    /// number the view model computes.
    private var cardFrames: [Int: ClientTexture] = [:]
    /// Map thumbnails (`gameliststage.img`) keyed by map id.
    private var stageThumbs: [Int: ClientTexture] = [:]
    private var font: LoadedFont?
    private var audio: ClientAudioPlayer?
    private var textFont: LoadedFont?
    /// Widget tree — currently just the shared buddy panel, hidden until the
    /// BUDDY button toggles `viewModel.isBuddyPanelVisible`.
    private var rootWidget = Widget()
    private var chatPanel: LobbyChatWidget?
    private var channelPanel: ChannelUserListWidget?
    private var buddyPanel: BuddyPanelWidget?
    private var createRoomDialog: CreateRoomDialogWidget?
    private var enterNumberDialog: EnterRoomNumberDialogWidget?

    public init(viewModel: GameRoomListViewModel) {
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

        // Card backgrounds (1–6), status icons (7–9), game-mode labels
        // (10–13), and the padlock (15) all live as extra frames of the
        // background sheet; load each frame the card renderer can ask for.
        for frame in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15] {
            cardFrames[frame] = renderer.texture(named: viewModel.backgroundImageName, frame: frame, assets: assets)
        }

        // The cards' map thumbnails (`gameliststage.img`, frame = map id).
        let thumbCount = (try? assets.image(named: viewModel.stageThumbImageName).count) ?? 0
        for frame in 0..<min(thumbCount, 11) {
            stageThumbs[frame] = renderer.texture(named: viewModel.stageThumbImageName, frame: frame, assets: assets)
        }

        font = LoadedFont(.numberFont, renderer: renderer, assets: assets)
        textFont = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        // Button rects are decomp-confirmed constants on the view model
        // (`State03_GameRoomList_CreateButtons`); just load the artwork.
        buttonSprites = viewModel.buttons.map { ButtonSprite(name: $0.name, renderer: renderer, assets: assets) }

        rootWidget = Widget(frame: Rect(x: 0, y: 0, width: 800, height: 600))

        // The lobby chat panel — always-visible chrome at the decomp rect,
        // fed by 0x201F broadcasts; Enter in its input sends 0x2010.
        // The 8 channel tabs (b_gamelist_ch1…8): frame 0 = normal, 3 = the
        // yellow selected state.
        let channelTabs = (1...8).map { n in
            (normal: renderer.texture(named: "b_gamelist_ch\(n).img", frame: 0, assets: assets),
             selected: renderer.texture(named: "b_gamelist_ch\(n).img", frame: 3, assets: assets))
        }
        let chatPanel = LobbyChatWidget(
            font: textFont,
            background: renderer.texture(named: viewModel.chatBackImageName, assets: assets),
            channelTabs: channelTabs
        )
        chatPanel.onSend = { [weak viewModel = self.viewModel] line in
            viewModel?.sendChat(line)
        }
        rootWidget.add(chatPanel)
        self.chatPanel = chatPanel

        // The CHANNEL user-list panel — always-visible lobby chrome at the
        // decomp rect, fed from the join-channel roster + 0x200E pushes.
        let channelPanel = ChannelUserListWidget(
            font: textFont,
            background: renderer.texture(named: viewModel.channelBackImageName, assets: assets)
        )
        rootWidget.add(channelPanel)
        self.channelPanel = channelPanel

        // The shared buddy panel — built once, hidden until BUDDY toggles it.
        let buddyBack = renderer.texture(named: viewModel.buddyBackImageName, assets: assets)
        let (panelWidth, panelHeight) = renderer.size(of: buddyBack)
        let panelFrame = panelWidth > 0
            ? Rect(x: 568, y: 11, width: panelWidth, height: panelHeight)
            : BuddyPanelWidget.defaultFrame
        let buddyPanel = BuddyPanelWidget(
            frame: panelFrame,
            font: textFont,
            background: buddyBack,
            addTexture: renderer.texture(named: viewModel.buddyAddImageName, assets: assets),
            delTexture: renderer.texture(named: viewModel.buddyDelImageName, assets: assets),
            closeTexture: renderer.texture(named: viewModel.buddyCloseImageName, assets: assets)
        )
        buddyPanel.isHidden = true
        buddyPanel.onClose = { [weak viewModel = self.viewModel] in viewModel?.dismissBuddyPanel() }
        buddyPanel.onAdd = { [weak viewModel = self.viewModel] name in viewModel?.addBuddy(named: name) }
        buddyPanel.onDelete = { [weak viewModel = self.viewModel] name in viewModel?.removeBuddy(named: name) }
        rootWidget.add(buddyPanel)
        self.buddyPanel = buddyPanel

        // Modal room dialogs — added after the panel so they sit topmost when
        // shown; both centered like the shared error dialog.
        func centered(_ imageName: String) -> (ClientTexture?, Rect) {
            let texture = renderer.texture(named: imageName, assets: assets)
            let (w, h) = renderer.size(of: texture)
            let frame = w > 0
                ? Rect(x: (800 - w) / 2, y: (600 - h) / 2, width: w, height: h)
                : Rect(x: 250, y: 200, width: 300, height: 200)
            return (texture, frame)
        }
        let okTexture = renderer.texture(named: viewModel.dialogOKImageName, assets: assets)
        let cancelTexture = renderer.texture(named: viewModel.dialogCancelImageName, assets: assets)

        let (createBack, createFrame) = centered(viewModel.createBackImageName)
        let createRoomDialog = CreateRoomDialogWidget(
            frame: createFrame, font: textFont, background: createBack,
            okTexture: okTexture, cancelTexture: cancelTexture
        )
        createRoomDialog.isHidden = true
        createRoomDialog.onSubmit = { [weak viewModel = self.viewModel] name, password, capacity in
            viewModel?.createRoom(name: name, password: password, capacity: capacity)
        }
        createRoomDialog.onCancel = { [weak viewModel = self.viewModel] in viewModel?.dismissDialogs() }
        rootWidget.add(createRoomDialog)
        self.createRoomDialog = createRoomDialog

        // The DIRECT GO dialog opens at its runtime initial rect (243,202) —
        // roughly centered — from a gbview dump. (It's draggable, so a later
        // capture at (459,33) was just a dragged position.)
        let directBack = renderer.texture(named: viewModel.directGoBackImageName, assets: assets)
        let (directWidth, directHeight) = renderer.size(of: directBack)
        let directFrame = directWidth > 0
            ? Rect(x: 243, y: 202, width: directWidth, height: directHeight)
            : Rect(x: 243, y: 202, width: 314, height: 160)
        let enterNumberDialog = EnterRoomNumberDialogWidget(
            frame: directFrame, font: textFont, background: directBack,
            okTexture: okTexture, cancelTexture: cancelTexture
        )
        enterNumberDialog.isHidden = true
        enterNumberDialog.onSubmit = { [weak viewModel] number, password in
            viewModel?.joinRoomByNumber(number, password: password)
        }
        enterNumberDialog.onCancel = { [weak viewModel] in viewModel?.dismissDialogs() }
        rootWidget.add(enterNumberDialog)
        self.enterNumberDialog = enterNumberDialog
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        buttonSprites = []
        cardFrames = [:]
        stageThumbs = [:]
        font = nil
        textFont = nil
        audio?.stop()
        audio = nil
        rootWidget = Widget()
        chatPanel = nil
        channelPanel = nil
        buddyPanel = nil
        createRoomDialog = nil
        enterNumberDialog = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        // The buddy panel (when shown) gets first crack and swallows clicks
        // that land on it; otherwise input falls through to the view model.
        if rootWidget.dispatch(event) {
            return
        }
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        audio?.update(deltaTime: deltaTime)
        viewModel.update(deltaTime: deltaTime)
        // Mirror the view model's live rosters/toggles onto the widgets.
        if let chatPanel, chatPanel.messages != viewModel.chatMessages {
            chatPanel.messages = viewModel.chatMessages
        }
        channelPanel?.users = viewModel.channelUsers
        if let buddyPanel {
            buddyPanel.isHidden = !viewModel.isBuddyPanelVisible
            buddyPanel.buddies = viewModel.buddies
        }
        // Mirror the modal dialogs, resetting their fields as they open.
        if let dialog = createRoomDialog {
            if viewModel.isCreateRoomDialogVisible, dialog.isHidden { dialog.reset() }
            dialog.isHidden = !viewModel.isCreateRoomDialogVisible
        }
        if let dialog = enterNumberDialog {
            if viewModel.isEnterNumberDialogVisible, dialog.isHidden { dialog.reset() }
            dialog.isHidden = !viewModel.isEnterNumberDialogVisible
        }
        rootWidget.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)

        let visibleRooms = viewModel.visibleRooms
        for (index, room) in visibleRooms.enumerated() {
            let rect = viewModel.roomRect(at: index)
            let rightColumn = index / 3 != 0

            // Card background — frame 1–6 by column, joined, and hover/select
            // state (RenderRoomCard).
            if let card = cardFrames[viewModel.cardFrame(forVisibleSlot: index)] {
                renderer.draw(card, in: rect, tint: nil)
            }

            // Draws a `gamelist_back.img` icon frame at a card-relative offset,
            // at its own natural size.
            func drawIcon(_ frame: Int, atX offsetX: Float, y offsetY: Float) {
                guard let icon = cardFrames[frame] else { return }
                let (w, h) = renderer.size(of: icon)
                renderer.draw(icon, in: Rect(x: rect.x + offsetX, y: rect.y + offsetY, width: w, height: h), tint: nil)
            }

            // The room's map thumbnail (RenderRoomCard's `gameliststage`
            // blit at card-relative (0x6a, 0x21)).
            if let thumb = stageThumbs[viewModel.stageThumbFrame(of: room)] ?? stageThumbs[0] {
                let (w, h) = renderer.size(of: thumb)
                renderer.draw(thumb, in: Rect(
                    x: rect.x + GameRoomListViewModel.stageThumbOffset.x,
                    y: rect.y + GameRoomListViewModel.stageThumbOffset.y,
                    width: w, height: h
                ), tint: nil)
            }

            // Status (PLAY/FULL/WAIT), game-mode label (SOLO…JEWEL), and the
            // padlock when the room is private — all at their decomp offsets.
            drawIcon(viewModel.statusFrame(of: room),
                     atX: GameRoomListViewModel.statusIconOffset.x, y: GameRoomListViewModel.statusIconOffset.y)
            drawIcon(viewModel.modeFrame(of: room),
                     atX: GameRoomListViewModel.modeIconOffset.x, y: GameRoomListViewModel.modeIconOffset.y)
            if room.isLocked {
                drawIcon(15, atX: GameRoomListViewModel.lockIconX(rightColumn: rightColumn),
                         y: GameRoomListViewModel.lockIconOffsetY)
            }

            // Bitmap-font text in the card's top strip: room number + name on
            // the left, and the players/max count flanking the "/" baked into
            // the card art near the right edge (the decomp's `%d` / count
            // overlays).
            if let font {
                let numberText = "\(room.id.rawValue)"
                font.draw(numberText, x: rect.x + 12, y: rect.y + 8, using: renderer)
                textFont?.draw(room.name, x: rect.x + 12 + font.width(of: numberText) + 8, y: rect.y + 8, using: renderer)
                // The baked separator sits at ~x+198; count numbers flank it.
                let players = "\(room.playerCount)"
                font.draw(players, x: rect.x + 194 - font.width(of: players), y: rect.y + 8, using: renderer)
                font.draw("\(room.capacity.rawValue)", x: rect.x + 203, y: rect.y + 8, using: renderer)
            }
        }

        for (index, button) in viewModel.buttons.enumerated() {
            // Each button draws the frame for its current state: the current
            // filter shows `selected` (yellow), the rest resolve to
            // pressed/hovered/default from the pointer.
            let state: ButtonState
            if viewModel.isFilterActive(button.action) {
                state = .selected
            } else if index == viewModel.pressedButtonIndex {
                state = .pressed
            } else if index == viewModel.hoveredButtonIndex {
                state = .hovered
            } else {
                state = .normal
            }
            guard let texture = buttonSprites[index].texture(for: state) else { continue }
            renderer.draw(texture, in: button.rect, tint: nil)
        }

        // The buddy panel draws on top of everything when shown.
        rootWidget.draw(renderer)
    }
}
