import GunBound

/// The scroll widget — the counterpart of the original's `CScrollBar`
/// (`CreateScrollListWidget`, `0x5080a0`; see GunBound-Decomp
/// `docs/widgets.md`), which auto-creates two arrow child buttons at the
/// track's ends, steps its position ±1 per arrow click clamped to
/// `total − pageSize`, and fires **`0x2000` + the new position** up to its
/// parent panel on any change.
///
/// This port keeps that shape: `upArrow`/`downArrow` are `ButtonWidget`
/// children (textureless by default, acting as hit zones over arrow art
/// baked into a panel sheet), position changes fire both the decomp-faithful
/// `Command(id: 0x2000 + position)` up the tree and the Swift-idiomatic
/// `onScroll` closure. An optional `thumbTexture` draws a proportional thumb
/// on the track. Pressing anywhere in the track (the arrow bands are already
/// claimed by the child buttons) starts a **drag**: position tracks the
/// pointer's vertical movement scaled to the track's travel, released by a
/// `pointerUp` anywhere — a real thumb-texture size isn't needed since the
/// drag is relative, not a hit-test against the drawn thumb.
@MainActor
public final class ScrollBarWidget: Widget {

    /// The command id base the original's scroll widget uses:
    /// `id = commandBase + position`.
    public static let commandBase = 0x2000

    /// Current scroll position, `0…maxPosition`.
    public private(set) var position = 0

    /// Total content lines; positions clamp to `contentCount - pageSize`.
    public var contentCount = 0 {
        didSet { position = min(position, maxPosition) }
    }

    /// How many content lines one page shows.
    public var pageSize = 1 {
        didSet { position = min(position, maxPosition) }
    }

    public var onScroll: ((Int) -> Void)?

    public let upArrow: ButtonWidget
    public let downArrow: ButtonWidget

    /// Optional proportional thumb drawn on the track between the arrows.
    public var thumbTexture: ClientTexture?

    public var maxPosition: Int { max(0, contentCount - pageSize) }

    /// The pointer's y and the position it started dragging from; `nil`
    /// when no drag is in progress.
    private var drag: (startY: Float, startPosition: Int)?

    /// - Parameters:
    ///   - track: the full track rect, arrows included (the decomp's arrows
    ///     are 18×18 children at the track's top and bottom).
    ///   - arrowSize: the height of each arrow hit zone.
    public convenience init(track: Rect, arrowSize: Float = 18) {
        self.init(
            track: track,
            upArrow: Rect(x: track.x, y: track.y, width: track.width, height: arrowSize),
            downArrow: Rect(x: track.x, y: track.y + track.height - arrowSize, width: track.width, height: arrowSize)
        )
    }

    /// Explicit arrow hit-zones — for panels whose baked knob art sits
    /// *outside* the decomp's track rect (the round knobs on the lobby
    /// chat/channel/buddy panels and the world list all render above and
    /// below their `CreateScrollListWidget` rect, so zones computed from the
    /// track ends miss them; positions measured from the extracted art).
    public init(track: Rect, upArrow: Rect, downArrow: Rect) {
        self.upArrow = ButtonWidget(frame: upArrow)
        self.downArrow = ButtonWidget(frame: downArrow)
        super.init(frame: track)
        add(self.upArrow)
        add(self.downArrow)
        self.upArrow.onClick = { [weak self] in self?.step(-1) }
        self.downArrow.onClick = { [weak self] in self?.step(1) }
    }

    public func step(_ delta: Int) {
        setPosition(position + delta)
    }

    public func setPosition(_ newPosition: Int) {
        let clamped = min(max(0, newPosition), maxPosition)
        guard clamped != position else { return }
        position = clamped
        onScroll?(position)
        send(Command(id: Self.commandBase + position, value: position))
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        switch event {
        case .pointerDown(let x, let y):
            // The arrow bands are children and already claimed pointerDowns
            // over themselves before dispatch reaches here, so any hit
            // inside our own frame is the track/thumb area.
            guard maxPosition > 0, frame.contains(x: x, y: y) else { return false }
            drag = (startY: y, startPosition: position)
            return true
        case .pointerMoved(_, let y):
            guard let drag else { return false }
            let arrowHeight = upArrow.frame.height
            let travel = frame.height - 2 * arrowHeight
            guard travel > 0 else { return true }
            let delta = Int(((y - drag.startY) / travel * Float(maxPosition)).rounded())
            setPosition(drag.startPosition + delta)
            return true
        case .pointerUp:
            guard drag != nil else { return false }
            drag = nil
            return true
        case .activate, .text, .key, .scroll:
            return false
        }
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        guard let thumbTexture, maxPosition > 0 else { return }
        let (thumbWidth, thumbHeight) = renderer.size(of: thumbTexture)
        let arrowHeight = upArrow.frame.height
        let innerTop = frame.y + arrowHeight
        let travel = frame.height - 2 * arrowHeight - thumbHeight
        guard travel > 0 else { return }
        let y = innerTop + travel * Float(position) / Float(maxPosition)
        renderer.draw(
            thumbTexture,
            in: Rect(x: frame.x + (frame.width - thumbWidth) / 2, y: y, width: thumbWidth, height: thumbHeight),
            tint: nil
        )
    }
}
