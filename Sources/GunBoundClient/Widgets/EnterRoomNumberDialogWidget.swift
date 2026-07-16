import GunBound
import GunBoundProtocol

/// The "enter room by number" (DIRECT GO) dialog — the port of the decomp's
/// `BuildEnterRoomNumberDialog` (`0x557df0`, button `0xf`,
/// `b_gamelist_directgo`; msg `0x2715`): a modal panel with a **Room No.** and
/// a **Password** field plus Ok/Cancel buttons. Submitting joins by number
/// (`0x2110`, the typed value clamped 1…1000) with the optional password.
///
/// Layout is runtime-confirmed from `gbview` dumps (panel id 1, 314×160):
/// two `0x557c84` text fields at panel-relative (99,50)/(99,84) 180×12, and
/// the two `0x557da0` label buttons — **Ok on the left** (id 1, (128,118)) and
/// **Cancel on the right** (id 0, (213,118)), both 82×34. The dialog opens at
/// its initial rect **(243,202)** (roughly centered) and is **draggable** by
/// its chrome (a movable panel — `m_pinned` clear in the decomp).
@MainActor
public final class EnterRoomNumberDialogWidget: Widget {

    /// Valid room numbers, matching the decomp's `_atol` clamp.
    public static let numberRange = 1...1000

    public let numberField: TextFieldWidget
    public let passwordField: TextFieldWidget
    public let okButton: ButtonWidget
    public let cancelButton: ButtonWidget

    /// Fired when Ok is pressed with a valid number, carrying the parsed
    /// number and the (possibly empty) password.
    public var onSubmit: ((Int, String) -> Void)?
    public var onCancel: (() -> Void)?

    public var backgroundTexture: ClientTexture?

    /// The panel's start origin — `reset()` (called each time it opens)
    /// returns it here, so a drag doesn't persist across re-opens (the
    /// original rebuilds the dialog fresh at its fixed spot).
    private let initialOrigin: (x: Float, y: Float)

    public init(
        frame: Rect,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        okTexture: ClientTexture? = nil,
        cancelTexture: ClientTexture? = nil
    ) {
        self.backgroundTexture = background
        self.initialOrigin = (frame.x, frame.y)

        // Panel-relative rects from the runtime dump.
        numberField = TextFieldWidget(
            frame: Rect(x: frame.x + 99, y: frame.y + 50, width: 180, height: 12),
            font: font
        )
        numberField.characterFilter = { $0.isNumber }
        numberField.maxLength = 4
        passwordField = TextFieldWidget(
            frame: Rect(x: frame.x + 99, y: frame.y + 84, width: 180, height: 12),
            font: font
        )
        passwordField.isSecure = true
        passwordField.maxLength = 16
        okButton = ButtonWidget(
            frame: Rect(x: frame.x + 128, y: frame.y + 118, width: 82, height: 34),
            texture: okTexture
        )
        cancelButton = ButtonWidget(
            frame: Rect(x: frame.x + 213, y: frame.y + 118, width: 82, height: 34),
            texture: cancelTexture
        )

        super.init(frame: frame)
        isDraggable = true  // a movable dialog (m_pinned clear in the decomp)
        add(numberField)
        add(passwordField)
        add(okButton)
        add(cancelButton)

        numberField.onSubmit = { [weak self] in self?.submit() }
        passwordField.onSubmit = { [weak self] in self?.submit() }
        okButton.onClick = { [weak self] in self?.submit() }
        cancelButton.onClick = { [weak self] in self?.onCancel?() }
    }

    public func reset() {
        moveBy(dx: initialOrigin.x - frame.x, dy: initialOrigin.y - frame.y)  // undo any drag
        numberField.setText("")
        passwordField.setText("")
        numberField.focus()  // ready to type immediately
    }

    private func submit() {
        guard let value = Int(numberField.text), Self.numberRange.contains(value) else { return }
        onSubmit?(value, passwordField.text)
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // A press on the chrome (not a field/button, which consume first) drags
        // the whole dialog; a move drags it, a release drops it.
        if handleDrag(event) { return true }
        // Otherwise modal within its bounds.
        switch event {
        case .pointerDown(let x, let y):
            return frame.contains(x: x, y: y)
        case .scroll(let x, let y, _):
            return frame.contains(x: x, y: y)
        case .pointerMoved, .pointerUp, .activate, .text, .key:
            return false
        }
    }
}
