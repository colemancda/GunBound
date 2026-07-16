import GunBound
import GunBoundProtocol

/// The Create Room dialog — the port of the decomp's `BuildCreateRoomDialog`
/// (button `4`, `b_gamelist_create`; `docs/screens/03_game_room_list.md`): a
/// modal panel with a room-name field (id 0), a password field (id 1), a
/// capacity selector, and OK/Cancel buttons (ids 8/9). Submitting sends
/// `SendCreateRoom` → `0x2120`.
///
/// Field/button positions are the decomp's confirmed offsets, relative to the
/// dialog panel's origin (the screen supplies the panel frame from the loaded
/// `gamelist_create.img`). The decomp's exact 8-box player-limit picker isn't
/// reproduced (it maps to per-msg-id baked box art we don't model); instead
/// the capacity is a click-to-cycle selector over our `RoomCapacity` cases,
/// drawn as text — functional, and flagged for a later art-faithful pass.
@MainActor
public final class CreateRoomDialogWidget: Widget {

    // Decomp offsets (relative to the dialog origin), from BuildCreateRoomDialog.
    static let nameFieldOffset = Rect(x: 0x60, y: 0x2c, width: 0xbe, height: 0xc)
    static let passwordFieldOffset = Rect(x: 0x60, y: 0x46, width: 0xbe, height: 0xc)
    static let okOffset = Rect(x: 0xd5, y: 0x99, width: 0x52, height: 0x22)
    static let cancelOffset = Rect(x: 0x80, y: 0x99, width: 0x52, height: 0x22)
    /// The decomp's player-limit picker row (`y=8`, from `x=0xad`); reused
    /// here as the click-to-cycle capacity region.
    static let capacityOffset = Rect(x: 0xad, y: 0x8, width: 0x52, height: 0x14)

    static let capacities: [RoomCapacity] = [._1_1, ._2_2, ._3_3, ._4_4]

    public let nameField: TextFieldWidget
    public let passwordField: TextFieldWidget
    public let okButton: ButtonWidget
    public let cancelButton: ButtonWidget
    public private(set) var capacity: RoomCapacity = ._4_4

    /// Fired when OK is pressed, with the entered name, password, and capacity.
    public var onSubmit: ((_ name: String, _ password: String, _ capacity: RoomCapacity) -> Void)?
    public var onCancel: (() -> Void)?

    public var backgroundTexture: ClientTexture?
    private let font: LoadedFont?
    private let textTint: (r: UInt8, g: UInt8, b: UInt8)

    public init(
        frame: Rect,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        okTexture: ClientTexture? = nil,
        cancelTexture: ClientTexture? = nil,
        textTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.font = font
        self.backgroundTexture = background
        self.textTint = textTint

        func place(_ o: Rect) -> Rect { Rect(x: frame.x + o.x, y: frame.y + o.y, width: o.width, height: o.height) }
        nameField = TextFieldWidget(frame: place(Self.nameFieldOffset), font: font)
        passwordField = TextFieldWidget(frame: place(Self.passwordFieldOffset), font: font, isSecure: true)
        okButton = ButtonWidget(frame: place(Self.okOffset), texture: okTexture)
        cancelButton = ButtonWidget(frame: place(Self.cancelOffset), texture: cancelTexture)
        nameField.maxLength = 30
        passwordField.maxLength = 16
        let capacityButton = ButtonWidget(frame: place(Self.capacityOffset))

        super.init(frame: frame)
        add(nameField)
        add(passwordField)
        add(capacityButton)
        add(okButton)
        add(cancelButton)

        // One field focused at a time; Enter moves name → password → submit.
        nameField.onFocus = { [weak self] in self?.passwordField.blur() }
        passwordField.onFocus = { [weak self] in self?.nameField.blur() }
        nameField.onSubmit = { [weak self] in self?.passwordField.focus() }
        passwordField.onSubmit = { [weak self] in self?.submit() }
        okButton.onClick = { [weak self] in self?.submit() }
        cancelButton.onClick = { [weak self] in self?.onCancel?() }
        capacityButton.onClick = { [weak self] in self?.cycleCapacity() }
    }

    /// Clears the fields and resets the capacity — called when the dialog is
    /// (re)opened.
    public func reset() {
        nameField.setText("")
        passwordField.setText("")
        nameField.blur()
        passwordField.blur()
        capacity = ._4_4
    }

    private func submit() {
        onSubmit?(nameField.text, passwordField.text, capacity)
    }

    public func cycleCapacity() {
        let index = Self.capacities.firstIndex(of: capacity) ?? Self.capacities.count - 1
        capacity = Self.capacities[(index + 1) % Self.capacities.count]
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        // The current capacity, drawn over the picker region (e.g. "4 vs 4").
        if let font {
            let players = Int(capacity.rawValue)
            font.draw("\(players / 2) vs \(players / 2)",
                      x: frame.x + Self.capacityOffset.x, y: frame.y + Self.capacityOffset.y + 3,
                      tint: textTint, using: renderer)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Modal within its bounds; a click that misses every child blurs the
        // text fields.
        switch event {
        case .pointerDown(let x, let y):
            if frame.contains(x: x, y: y) {
                nameField.blur()
                passwordField.blur()
                return true
            }
            return false
        case .scroll(let x, let y, _):
            return frame.contains(x: x, y: y)
        case .pointerMoved, .pointerUp, .activate, .text, .key:
            return false
        }
    }
}
