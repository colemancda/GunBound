import GunBound

/// The Server Select screen's WORLD LIST panel — the Swift counterpart of the
/// decomp's `CWorldListPanel` (`CPanel` subclass, vtable `0x557f08`, built by
/// `BuildWorldListPanel` `0x5099d0`). Like the original panel it composes, in
/// one cohesive widget:
///
/// - the panel background and the **server-row grid** (two columns of state-
///   coloured rows with number/name/description text and a population dial),
/// - the two **View All / Friends tab buttons** (`m_tabSelected` radio pair —
///   View All is the default selection), and
/// - the **row scrollbar** (a `ScrollBarWidget` child).
///
/// It owns only presentation and hit-testing; all state and side effects stay
/// in `ServerSelectViewModel` (the decomp put that logic in the panel because
/// it had no view-model layer). Tab clicks call `selectWorldListView`, row
/// clicks call `selectRow`, and the scrollbar calls `setScrollOffset`. The
/// bottom-bar buttons (Exit / Buddy / SERVER) are *not* part of this panel —
/// they're separate flat buttons the screen draws, matching the original.
@MainActor
public final class WorldListPanelWidget: Widget {

    private unowned let viewModel: ServerSelectViewModel
    private let font: LoadedFont?
    private let panelTexture: ClientTexture?
    /// server_list.img frames 1/3/4: base, highlighted, offline row states.
    private let rowBaseTexture: ClientTexture?
    private let rowSelectedTexture: ClientTexture?
    private let rowOfflineTexture: ClientTexture?
    /// server_list.img frames 5–9: the five population-gauge levels.
    private let gaugeTextures: [ClientTexture?]

    private let viewAllSprite: ButtonSprite
    private let friendsSprite: ButtonSprite
    private let viewAllRect: Rect
    private let friendsRect: Rect
    private let scrollBar: ScrollBarWidget

    /// Local tab hover/press (0 = View All, 1 = Friends). The panel owns these,
    /// separate from the bottom-bar buttons' `ServerSelectViewModel` state.
    private var hoveredTab: Int?
    private var pressedTab: Int?

    /// Pale cyan for descriptions — the decomp's flat RGB565 `0xb77f`.
    private static let descriptionTint: (r: UInt8, g: UInt8, b: UInt8) = (181, 239, 255)

    public init(
        viewModel: ServerSelectViewModel,
        font: LoadedFont?,
        panelTexture: ClientTexture?,
        rowBaseTexture: ClientTexture?,
        rowSelectedTexture: ClientTexture?,
        rowOfflineTexture: ClientTexture?,
        gaugeTextures: [ClientTexture?],
        viewAllSprite: ButtonSprite,
        friendsSprite: ButtonSprite
    ) {
        self.viewModel = viewModel
        self.font = font
        self.panelTexture = panelTexture
        self.rowBaseTexture = rowBaseTexture
        self.rowSelectedTexture = rowSelectedTexture
        self.rowOfflineTexture = rowOfflineTexture
        self.gaugeTextures = gaugeTextures
        self.viewAllSprite = viewAllSprite
        self.friendsSprite = friendsSprite
        self.viewAllRect = viewModel.buttons.first { $0.name == "b_server_all.img" }?.rect ?? .zero
        self.friendsRect = viewModel.buttons.first { $0.name == "b_server_friend.img" }?.rect ?? .zero

        // The panel's scroll widget (typeId 4) and its two arrow children —
        // exact rects from a runtime panel-tree dump (`gbview`), replacing the
        // earlier eyeballed values. The arrow knobs are baked into the panel
        // chrome; these are the invisible hit-zones over them.
        let scrollBar = ScrollBarWidget(
            track: Rect(x: 526, y: 87, width: 18, height: 377),
            upArrow: Rect(x: 526, y: 59, width: 18, height: 18),
            downArrow: Rect(x: 526, y: 474, width: 18, height: 18)
        )
        scrollBar.pageSize = ServerSelectViewModel.maxVisibleRows / ServerSelectViewModel.rowColumns
        scrollBar.onScroll = { [weak viewModel] position in
            viewModel?.setScrollOffset(position)
        }
        self.scrollBar = scrollBar

        super.init(frame: viewModel.panelRect)
        add(scrollBar)
    }

    public override func update(deltaTime: Double) {
        scrollBar.contentCount = viewModel.lineCount
        super.update(deltaTime: deltaTime)
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let panelTexture {
            renderer.draw(panelTexture, in: viewModel.panelRect, tint: nil)
        }
        drawRows(renderer)
        drawTabs(renderer)
    }

    private func drawRows(_ renderer: ClientRenderer) {
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

            // Server number (wire id + 1) at x+10, name at x+32, both centered
            // at y+8; up to two description lines fill the body band at y+30
            // with a 14px pitch, in the original's pale cyan.
            if let font {
                font.draw("\(server.id + 1)", x: rect.x + 10, y: rect.y + 8, using: renderer)
                font.draw(server.name, x: rect.x + 32, y: rect.y + 8, using: renderer)
                let descriptionLines = server.descriptionText
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .prefix(2)
                for (line, text) in descriptionLines.enumerated() {
                    font.draw(
                        String(text).trimmingCharacters(in: .whitespaces),
                        x: rect.x + 12,
                        y: rect.y + 30 + Float(line) * 14,
                        tint: Self.descriptionTint,
                        using: renderer
                    )
                }
            }

            // Population gauge (F/E dial) beside the row.
            if let gauge = gaugeTextures[viewModel.populationLevel(of: server)] {
                renderer.draw(gauge, in: viewModel.gaugeRect(at: index), tint: nil)
            }
        }
    }

    private func drawTabs(_ renderer: ClientRenderer) {
        drawTab(viewAllSprite, rect: viewAllRect, tab: 0, selected: viewModel.worldListFilter == .all, renderer)
        drawTab(friendsSprite, rect: friendsRect, tab: 1, selected: viewModel.worldListFilter == .friends, renderer)
    }

    private func drawTab(_ sprite: ButtonSprite, rect: Rect, tab: Int, selected: Bool, _ renderer: ClientRenderer) {
        let state: ButtonState
        if selected {
            // The current view stays on its `selected` (yellow) frame rather
            // than flashing `pressed`.
            state = .selected
        } else if pressedTab == tab {
            state = .pressed
        } else if hoveredTab == tab {
            state = .hovered
        } else {
            state = .normal
        }
        if let texture = sprite.texture(for: state) {
            renderer.draw(texture, in: rect, tint: nil)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        switch event {
        case let .pointerMoved(x, y):
            hoveredTab = tab(at: x, y: y)
            return false  // let hover also reach the view model's bottom bar

        case let .pointerDown(x, y):
            if let tab = tab(at: x, y: y) {
                pressedTab = tab
                viewModel.selectWorldListView(tab == 0 ? .all : .friends)
                return true
            }
            return viewModel.selectRow(atPoint: x, y: y)

        case .pointerUp:
            pressedTab = nil
            return false

        case .activate, .text, .key, .scroll:
            return false
        }
    }

    /// The tab index (0 = View All, 1 = Friends) under a point, or `nil`.
    private func tab(at x: Float, y: Float) -> Int? {
        if viewAllRect.contains(x: x, y: y) { return 0 }
        if friendsRect.contains(x: x, y: y) { return 1 }
        return nil
    }
}
