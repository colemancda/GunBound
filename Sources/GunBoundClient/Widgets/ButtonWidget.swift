import GunBound

/// A clickable leaf — the counterpart of the original's `CButton`
/// (`CreateButtonWidget`). Draws its texture (hover-tinted) and fires
/// `onClick` on pointer-down inside its frame; textureless buttons act as
/// invisible hit zones over artwork baked into a panel sheet (e.g. the
/// world-list scrollbar's baked arrow knobs).
@MainActor
public final class ButtonWidget: Widget {

    public var texture: ClientTexture?
    /// Optional per-state artwork. When set, the button draws the frame for
    /// its current state (normal / hovered / pressed) instead of `texture`
    /// plus a hover tint — the frame-based path the toggle buttons use.
    public var sprite: ButtonSprite?
    public var hoverTint: (r: UInt8, g: UInt8, b: UInt8) = (200, 200, 255)
    /// When false the button ignores input and (with a `sprite`, if
    /// `showsDisabledFrame`) draws its `disabled` frame — the decomp's
    /// `SetEnabled(false)`.
    public var isEnabled = true {
        didSet {
            if !isEnabled { isHovered = false; isPressed = false }
        }
    }
    /// Whether a disabled button draws its greyed `disabled` frame. The
    /// original's enabled flag only *blocks input* — a live capture shows the
    /// world list's disabled scroll arrows still drawn with their normal art —
    /// so widgets that mirror that set this false; buttons whose disabled look
    /// is real (the SERVER button) leave it on.
    public var showsDisabledFrame = true
    public private(set) var isHovered = false
    /// Held down (armed on a press inside, released by any pointer-up) —
    /// the decomp's `+0x38` armed flag, which held arrow labels use to
    /// auto-repeat their action every frame.
    public private(set) var isPressed = false
    public var onClick: (() -> Void)?

    public init(frame: Rect, texture: ClientTexture? = nil) {
        self.texture = texture
        super.init(frame: frame)
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let sprite {
            let state: ButtonState
            if !isEnabled, showsDisabledFrame {
                state = .disabled
            } else if isPressed {
                state = .pressed
            } else if isHovered {
                state = .hovered
            } else {
                state = .normal
            }
            if let texture = sprite.texture(for: state) {
                renderer.draw(texture, in: frame, tint: nil)
            }
            return
        }
        guard let texture else { return }
        renderer.draw(texture, in: frame, tint: isHovered ? hoverTint : nil)
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        switch event {
        case .pointerMoved(let x, let y):
            isHovered = isEnabled && frame.contains(x: x, y: y)
            return false  // hover tracking never consumes the event
        case .pointerDown(let x, let y):
            guard isEnabled, frame.contains(x: x, y: y) else { return false }
            isPressed = true
            onClick?()
            return true
        case .pointerUp:
            isPressed = false
            return false  // release isn't consumed; siblings see it too
        case .activate, .text, .key, .scroll:
            return false
        }
    }
}
