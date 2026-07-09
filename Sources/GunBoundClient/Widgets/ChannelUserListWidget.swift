import GunBound

/// The lobby's CHANNEL user-list panel — the port of the decomp's
/// `BuildChannelUserListPanel` (`0x509d80`, vtable `0x557cac`): a 209-wide
/// panel on the lobby's right side listing the channel's members, with a
/// page-7 scroll-list widget down its right edge. Its row renderer
/// (`RenderChannelUserRow`) draws a status flag + rank icon + name per user;
/// our roster carries names only, so rows are names (the icons need per-user
/// status/rank data the `0x2001`/`0x200E` packets do carry — a later pass can
/// thread them through).
///
/// Geometry is decomp-confirmed from the builder's field writes: the panel at
/// **(572, 287) 209×259** (`0x23c, 0x11f, 0xd1, 0x103`), the scrollbar at
/// panel-relative **(179, 63) 18×154** (`0xb3, 0x3f, 0x12, 0x9a`), page 7.
@MainActor
public final class ChannelUserListWidget: Widget {

    /// The decomp's fixed panel rect.
    public static let defaultFrame = Rect(x: 572, y: 287, width: 209, height: 259)

    /// Rows visible at once — the decomp scrollbar's page size.
    public static let visibleRows = 7

    /// Usernames shown in the list, in roster order.
    public var users: [String] = [] {
        didSet { scrollBar.contentCount = users.count }
    }

    public var backgroundTexture: ClientTexture?
    private let font: LoadedFont?
    private let textTint: (r: UInt8, g: UInt8, b: UInt8)

    public let scrollBar: ScrollBarWidget

    /// The list band's origin — decomp-confirmed from `RenderChannelUserRow`
    /// (`0x5074a0`): rows start at panel-relative y `0x25` (37) on a `0x1e`
    /// (30px) pitch; the status icon draws at x+9 and the rank icon at
    /// x+0x27 (39), with the name text after them. We don't draw the icons
    /// yet, so the name starts in the status-icon column.
    private var listOrigin: (x: Float, y: Float) { (frame.x + 9, frame.y + 37) }
    /// Decomp row pitch (`0x1e`).
    private var linePitch: Float { 30 }

    public init(
        frame: Rect = ChannelUserListWidget.defaultFrame,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        textTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.font = font
        self.backgroundTexture = background
        self.textTint = textTint
        // Decomp: CreateScrollListWidget(mgr, 0xb3, 0x3f, 0x12, 0x9a, 7).
        scrollBar = ScrollBarWidget(
            track: Rect(x: frame.x + 179, y: frame.y + 63, width: 18, height: 154),
            arrowSize: 18
        )
        scrollBar.pageSize = Self.visibleRows
        super.init(frame: frame)
        add(scrollBar)
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        guard let font else { return }
        let (originX, originY) = listOrigin
        for (row, name) in users.dropFirst(scrollBar.position).prefix(Self.visibleRows).enumerated() {
            font.draw(name, x: originX, y: originY + Float(row) * linePitch, tint: textTint, using: renderer)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Part of the screen chrome, not a modal: only the scrollbar children
        // consume input; clicks on the panel body fall through (nothing
        // behind it anyway at the decomp rect).
        _ = event
        return false
    }
}
