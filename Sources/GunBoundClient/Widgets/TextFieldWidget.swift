import GunBound

/// A single-line text-entry field — the widget the Create Room and Enter-Room-
/// By-Number dialogs build on (the decomp's text-entry widget class,
/// `BuildCreateRoomDialog`'s ids 0/1). It draws the current text (or a
/// placeholder) with a blinking caret while focused, and edits from the
/// `.text` / `.key` events the input model now carries.
///
/// Focus: clicking inside focuses the field and fires `onFocus` (a container
/// uses that to blur its other fields — dispatch stops at the first consumer,
/// so a field can't see clicks that land on a sibling). The caret is kept at
/// the end of the text (the decomp's simple end-caret blink); `.left`/`.right`
/// are accepted but not yet acted on.
@MainActor
public final class TextFieldWidget: Widget {

    public private(set) var text: String
    public var placeholder = ""
    /// Renders each character as `*` (password entry).
    public var isSecure = false
    /// Rejects characters that fail this test (e.g. digits-only for the
    /// room-number field). `nil` accepts any printable text.
    public var characterFilter: ((Character) -> Bool)?
    public var maxLength = 64

    public private(set) var isFocused = false

    /// Fired when the field gains focus (container blurs its siblings).
    public var onFocus: (() -> Void)?
    /// Fired on every edit, with the new text.
    public var onChange: ((String) -> Void)?
    /// Fired when Enter is pressed while focused.
    public var onSubmit: (() -> Void)?

    private let font: LoadedFont?
    private let textTint: (r: UInt8, g: UInt8, b: UInt8)
    private var blinkElapsed: Double = 0

    /// Caret on/off cadence — the original blinks a text caret on a ~20-frame
    /// (≈0.33s at 60fps) period; a full on+off cycle is twice that.
    public static let blinkHalfPeriod: Double = 0.5

    public init(
        frame: Rect,
        font: LoadedFont?,
        text: String = "",
        isSecure: Bool = false,
        textTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.text = text
        self.font = font
        self.isSecure = isSecure
        self.textTint = textTint
        super.init(frame: frame)
    }

    public func focus() {
        guard !isFocused else { return }
        isFocused = true
        blinkElapsed = 0
        onFocus?()
    }

    public func blur() {
        isFocused = false
    }

    public func setText(_ newText: String) {
        text = String(newText.prefix(maxLength))
        onChange?(text)
    }

    public override func update(deltaTime: Double) {
        if isFocused {
            blinkElapsed += deltaTime
        }
        super.update(deltaTime: deltaTime)
    }

    private var caretVisible: Bool {
        // On for the first half of each blink cycle.
        isFocused && (blinkElapsed.truncatingRemainder(dividingBy: Self.blinkHalfPeriod * 2) < Self.blinkHalfPeriod)
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        guard let font else { return }
        let inset: Float = 3
        let x = frame.x + inset
        let y = frame.y + max(0, (frame.height - font.lineHeight) / 2)

        let display = isSecure ? String(repeating: "*", count: text.count) : text
        if display.isEmpty, !isFocused, !placeholder.isEmpty {
            font.draw(placeholder, x: x, y: y, tint: (150, 150, 150), using: renderer)
            return
        }
        font.draw(display, x: x, y: y, tint: textTint, using: renderer)
        if caretVisible {
            // Draw a caret glyph just after the text (end-caret).
            font.draw("_", x: x + font.width(of: display), y: y, tint: textTint, using: renderer)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        switch event {
        case .pointerDown(let x, let y):
            if frame.contains(x: x, y: y) {
                focus()
                return true
            }
            blur()
            return false
        case .text(let string):
            guard isFocused else { return false }
            for character in string where text.count < maxLength {
                guard character != "\n", character != "\r" else { continue }
                if let characterFilter, !characterFilter(character) { continue }
                text.append(character)
            }
            onChange?(text)
            return true
        case .key(.backspace):
            guard isFocused else { return false }
            if !text.isEmpty { text.removeLast() }
            onChange?(text)
            return true
        case .key(.left), .key(.right):
            // Accepted but not yet acted on (end-caret only for now).
            return isFocused
        case .activate:
            guard isFocused else { return false }
            onSubmit?()
            return true
        case .pointerMoved:
            return false
        }
    }
}
