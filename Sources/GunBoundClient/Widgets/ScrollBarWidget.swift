import GunBound

/// The scroll widget — the counterpart of the original's `CScrollBar`
/// (`CreateScrollListWidget`, `0x5080a0`; fully promoted in GunBound-Decomp
/// `src/cxx/ScrollBar.cpp`), which auto-creates two arrow children at the
/// track's ends and fires **`0x2000` + the new position** up to its parent
/// panel on any change.
///
/// Decomp-confirmed interaction model, all ported here:
/// - **Thumb geometry** (`ThumbHeight` `0x50e050` / `IsOverThumb`
///   `0x50f770`): the thumb spans `pos·height/total` from the track top,
///   its height the page's share of the track floored at 10 and rounded
///   down to a multiple of 5; an empty list fills the whole track.
/// - **Thumb drag** (`OnMouseDown` `0x50f500`): a press on the thumb arms
///   dragging with a grab offset so the thumb doesn't jump under the
///   cursor; releases anywhere disarm (`OnMouseUp` `0x50f5f0`).
/// - **Held-track paging** (`Draw` `0x50f660`): while the track (not the
///   thumb) is held pressed, the position pages one `pageSize` per frame
///   toward the held point.
/// - **Held-arrow auto-repeat** (`OnCommand` `0x50f7c0`): a held arrow
///   steps ±1 every frame.
///
/// `upArrow`/`downArrow` are `ButtonWidget` children (textureless by
/// default, acting as hit zones over arrow art baked into a panel sheet);
/// position changes fire both the decomp-faithful
/// `Command(id: 0x2000 + position)` and the Swift-idiomatic `onScroll`
/// closure. An optional `thumbTexture` draws the thumb at the decomp
/// geometry. Per-frame behaviors (held paging/stepping) tick from
/// `update(deltaTime:)` — the original runs them from its per-frame draw.
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

    /// Optional thumb art, drawn at the decomp's thumb rect.
    public var thumbTexture: ClientTexture?

    public var maxPosition: Int { max(0, contentCount - pageSize) }

    /// `thumbTop - pointerY` at the grab (the decomp's `m_grabOffset`);
    /// `nil` when no thumb drag is in progress.
    private var dragGrabOffset: Float?
    /// The track (not the thumb) is held pressed — pages toward the
    /// pointer each frame (the decomp's `m_pressed`).
    private var isTrackPressed = false
    /// The last pointer position seen (the decomp's `m_lastX/m_lastY`).
    private var lastPointer: (x: Float, y: Float) = (0, 0)

    // MARK: Thumb geometry (decomp formulas)

    /// The thumb's height: the page's share of the track, floored at 10
    /// and rounded down to a multiple of 5; a bar with no content fills
    /// the whole track (`CScrollBar::ThumbHeight`).
    public var thumbHeight: Float {
        guard contentCount > 0 else { return frame.height }
        let share = Float(pageSize) * frame.height / Float(contentCount)
        return (max(10, share) / 5).rounded(.down) * 5
    }

    /// The thumb's top edge: `pos · height / total` from the track top
    /// (`CScrollBar::IsOverThumb`'s placement).
    public var thumbTop: Float {
        guard contentCount > 0 else { return frame.y }
        return frame.y + Float(position) * frame.height / Float(contentCount)
    }

    /// Whether a point is over the thumb (x within the track, y within
    /// the thumb span).
    public func isOverThumb(x: Float, y: Float) -> Bool {
        guard x >= frame.x, x <= frame.x + frame.width else { return false }
        return y >= thumbTop && y <= thumbTop + thumbHeight
    }

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
            lastPointer = (x, y)
            // The arrow bands are children and already claimed pointerDowns
            // over themselves before dispatch reached here (their held
            // auto-repeat runs from update). A thumb hit arms the drag with
            // the grab offset; any other press inside arms held paging.
            guard maxPosition > 0, frame.contains(x: x, y: y) else { return false }
            if isOverThumb(x: x, y: y) {
                dragGrabOffset = thumbTop - y
                isTrackPressed = false
            } else {
                isTrackPressed = true
            }
            return true
        case .pointerMoved(let x, let y):
            lastPointer = (x, y)
            guard let grab = dragGrabOffset else { return false }
            // Place the thumb top at the pointer plus the grab offset and
            // invert the thumb-top formula for the position.
            guard contentCount > 0, frame.height > 0 else { return true }
            let newTop = y + grab
            setPosition(Int(((newTop - frame.y) * Float(contentCount) / frame.height).rounded()))
            return true
        case .pointerUp(let x, let y):
            lastPointer = (x, y)
            let consumed = dragGrabOffset != nil || isTrackPressed
            dragGrabOffset = nil
            isTrackPressed = false
            return consumed
        case .activate, .text, .key, .scroll:
            return false
        }
    }

    /// The per-frame held behaviors the original runs from its draw pass:
    /// a held track pages toward the pointer, and held arrows auto-repeat
    /// their ±1 step.
    public override func update(deltaTime: Double) {
        super.update(deltaTime: deltaTime)
        if upArrow.isPressed { step(-1) }
        if downArrow.isPressed { step(1) }
        guard isTrackPressed, maxPosition > 0, !isOverThumb(x: lastPointer.x, y: lastPointer.y) else { return }
        if lastPointer.y < thumbTop {
            setPosition(position - pageSize)
        } else if lastPointer.y > thumbTop + thumbHeight {
            setPosition(position + pageSize)
        }
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        guard let thumbTexture, contentCount > 0 else { return }
        let (thumbWidth, _) = renderer.size(of: thumbTexture)
        renderer.draw(
            thumbTexture,
            in: Rect(x: frame.x + (frame.width - thumbWidth) / 2, y: thumbTop, width: thumbWidth, height: thumbHeight),
            tint: nil
        )
    }
}
