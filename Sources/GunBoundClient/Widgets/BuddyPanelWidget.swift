import GunBound

/// The shared buddy-list panel — the port of the decomp's `BuildBuddyPanel`
/// (`0x557be4`; GunBound-Decomp `docs/widgets.md`): a singleton panel keyed
/// 20000 at **(568, 11) 211×267** with Add (`0x2bd`) / Del (`0x2be`) /
/// close-X (`0x2bf`) buttons and a scroll-list widget (its own arrow
/// children) down the right edge. The lobby's BUDDY button and the Ready
/// Room both show/hide this same panel rather than rebuilding it.
///
/// This is the third consumer of the composite widget layer, after the
/// world-list scrollbar and the error dialog — it nests a `ScrollBarWidget`
/// and three `ButtonWidget`s under one panel and draws the buddy roster in
/// the list band, scrolled by the bar.
///
/// The panel's own rect (and `buddy_back.img`'s size) are decomp-confirmed;
/// the *interior* button/scrollbar positions are not recorded in the decomp,
/// so they're eyeballed against the panel art and documented as such (the
/// same footing as the Server Select scrollbar's baked-arrow hit zones).
@MainActor
public final class BuddyPanelWidget: Widget {

    /// The decomp's fixed panel rect — also `buddy_back.img`'s natural size.
    public static let defaultFrame = Rect(x: 568, y: 11, width: 211, height: 267)

    /// Buddy names shown in the list band; the counter reflects the count.
    public var buddies: [String] = [] {
        didSet { scrollBar.contentCount = buddies.count }
    }

    public var backgroundTexture: ClientTexture?
    private let font: LoadedFont?
    private let textTint: (r: UInt8, g: UInt8, b: UInt8)

    public let addButton: ButtonWidget
    public let delButton: ButtonWidget
    public let closeButton: ButtonWidget
    public let scrollBar: ScrollBarWidget

    /// How many buddy rows are visible at once (the list band height / line
    /// pitch). Drives the scrollbar's page size.
    public static let visibleRows = 11

    /// Called when the close-X is clicked (after the panel hides itself).
    public var onClose: (() -> Void)?
    public var onAdd: (() -> Void)?
    public var onDelete: (() -> Void)?

    /// The list band the roster is drawn into, inset inside the panel border
    /// (below the title bar, left of the scrollbar).
    private var listOrigin: (x: Float, y: Float) { (frame.x + 12, frame.y + 36) }
    private var linePitch: Float { (font?.lineHeight ?? 12) + 4 }

    public init(
        frame: Rect = BuddyPanelWidget.defaultFrame,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        addTexture: ClientTexture? = nil,
        delTexture: ClientTexture? = nil,
        closeTexture: ClientTexture? = nil,
        textTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.font = font
        self.backgroundTexture = background
        self.textTint = textTint

        // Interior positions (panel-relative, not decomp-recorded):
        //   close-X — far right of the title bar (25×22 art)
        //   Add / Del — bottom-left, side by side (42×22 art)
        //   scrollbar — right edge, below the title bar down to the bottom
        closeButton = ButtonWidget(
            frame: Rect(x: frame.x + frame.width - 29, y: frame.y + 5, width: 25, height: 22),
            texture: closeTexture
        )
        addButton = ButtonWidget(
            frame: Rect(x: frame.x + 10, y: frame.y + frame.height - 28, width: 42, height: 22),
            texture: addTexture
        )
        delButton = ButtonWidget(
            frame: Rect(x: frame.x + 56, y: frame.y + frame.height - 28, width: 42, height: 22),
            texture: delTexture
        )
        scrollBar = ScrollBarWidget(
            track: Rect(x: frame.x + frame.width - 26, y: frame.y + 34, width: 22, height: frame.height - 66),
            arrowSize: 20
        )
        scrollBar.pageSize = Self.visibleRows

        super.init(frame: frame)
        add(scrollBar)
        add(addButton)
        add(delButton)
        add(closeButton)

        closeButton.onClick = { [weak self] in self?.close() }
        addButton.onClick = { [weak self] in self?.onAdd?() }
        delButton.onClick = { [weak self] in self?.onDelete?() }
    }

    /// Hides the panel and fires `onClose`.
    public func close() {
        isHidden = true
        onClose?()
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        guard let font else { return }

        // Buddy count in the title bar (the "n/n" counter to the right of the
        // avatar icon baked into the panel art).
        font.draw("\(buddies.count)", x: frame.x + 34, y: frame.y + 7, tint: textTint, using: renderer)

        // The roster, scrolled by the bar: draw the visible window only.
        let start = scrollBar.position
        let (originX, originY) = listOrigin
        for (row, name) in buddies.dropFirst(start).prefix(Self.visibleRows).enumerated() {
            font.draw(name, x: originX, y: originY + Float(row) * linePitch, tint: textTint, using: renderer)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Modal within its own bounds: swallow clicks that land on the panel
        // (but not its children — they got first chance) so they don't fall
        // through to the screen behind. Clicks outside the panel pass through.
        switch event {
        case .pointerDown(let x, let y):
            return frame.contains(x: x, y: y)
        case .pointerMoved, .activate, .text, .key:
            return false
        }
    }
}
