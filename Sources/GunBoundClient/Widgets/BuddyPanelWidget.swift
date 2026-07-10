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
        didSet {
            scrollBar.contentCount = buddies.count
            if buddies != oldValue {
                selectedIndex = nil
            }
        }
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
    /// Called when a name typed into the Add field is submitted.
    public var onAdd: ((String) -> Void)?
    /// Called when Del is clicked with a roster row selected, with that
    /// buddy's name.
    public var onDelete: ((String) -> Void)?

    /// The roster row highlighted by a click — Del acts on it. Cleared
    /// when the roster changes out from under it.
    public private(set) var selectedIndex: Int?

    /// The inline name-entry field the Add button toggles (the decomp
    /// documents Add/Del only as label buttons with no captured entry
    /// flow, so the inline field is this port's own convention).
    public let addField: TextFieldWidget

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
        // The chrome's round knobs render outside the track (measured from
        // buddy_back.img: y 44–63 above, 234–253 below); the arrow hit-zones
        // sit on the knobs.
        scrollBar = ScrollBarWidget(
            track: Rect(x: frame.x + frame.width - 26, y: frame.y + 34, width: 22, height: frame.height - 66),
            upArrow: Rect(x: frame.x + 184, y: frame.y + 44, width: 24, height: 20),
            downArrow: Rect(x: frame.x + 184, y: frame.y + 234, width: 24, height: 20)
        )
        scrollBar.pageSize = Self.visibleRows

        // The Add field sits in the band between the roster and the
        // Add/Del buttons, hidden until Add toggles it open.
        addField = TextFieldWidget(
            frame: Rect(x: frame.x + 12, y: frame.y + frame.height - 52, width: 160, height: 16),
            font: font,
            textTint: textTint
        )
        addField.placeholder = "buddy name"
        addField.maxLength = 12  // Username's fixed wire length
        addField.isHidden = true

        super.init(frame: frame)
        add(scrollBar)
        add(addField)
        add(addButton)
        add(delButton)
        add(closeButton)

        closeButton.onClick = { [weak self] in self?.close() }
        addButton.onClick = { [weak self] in self?.toggleAddField() }
        delButton.onClick = { [weak self] in self?.deleteSelected() }
        addField.onSubmit = { [weak self] in self?.submitAddField() }
    }

    /// Add: opens (and focuses) the name field, or closes it if open.
    private func toggleAddField() {
        if addField.isHidden {
            addField.setText("")
            addField.isHidden = false
            addField.focus()
        } else {
            addField.isHidden = true
            addField.blur()
        }
    }

    private func submitAddField() {
        let name = addField.text.trimmingCharacters(in: .whitespaces)
        addField.isHidden = true
        addField.blur()
        guard !name.isEmpty else { return }
        onAdd?(name)
    }

    /// Del: removes the highlighted roster row, if any.
    private func deleteSelected() {
        guard let index = selectedIndex, buddies.indices.contains(index) else { return }
        onDelete?(buddies[index])
    }

    /// Hides the panel (and its add field) and fires `onClose`.
    public func close() {
        addField.isHidden = true
        addField.blur()
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

        // The roster, scrolled by the bar: draw the visible window only,
        // the selected row (Del's target) highlighted.
        let start = scrollBar.position
        let (originX, originY) = listOrigin
        for (row, name) in buddies.dropFirst(start).prefix(Self.visibleRows).enumerated() {
            let tint = (start + row == selectedIndex) ? (r: UInt8(255), g: UInt8(220), b: UInt8(120)) : textTint
            font.draw(name, x: originX, y: originY + Float(row) * linePitch, tint: tint, using: renderer)
        }
    }

    /// The visible roster row (absolute index into `buddies`) at a point,
    /// or `nil` outside the list band.
    private func rowIndex(atX x: Float, y: Float) -> Int? {
        let (originX, originY) = listOrigin
        // The band spans from the list origin down to the Add field's band,
        // left of the scrollbar.
        guard x >= originX, x < scrollBar.frame.x,
              y >= originY, y < frame.y + frame.height - 56 else { return nil }
        let row = Int((y - originY) / linePitch)
        guard row >= 0, row < Self.visibleRows else { return nil }
        let index = scrollBar.position + row
        return buddies.indices.contains(index) ? index : nil
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Modal within its own bounds: swallow clicks that land on the panel
        // (but not its children — they got first chance) so they don't fall
        // through to the screen behind. Clicks outside the panel pass through.
        switch event {
        case .pointerDown(let x, let y):
            guard frame.contains(x: x, y: y) else { return false }
            // A click in the list band selects (or re-clicks deselect) the
            // row under it — Del acts on the selection.
            if let index = rowIndex(atX: x, y: y) {
                selectedIndex = (selectedIndex == index) ? nil : index
            }
            return true
        case .scroll(let x, let y, let steps):
            guard frame.contains(x: x, y: y) else { return false }
            scrollBar.step(steps)
            return true
        case .pointerMoved, .pointerUp, .activate, .text, .key:
            return false
        }
    }
}
