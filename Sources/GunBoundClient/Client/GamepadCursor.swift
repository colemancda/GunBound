import GunBound

/// Drives the virtual pointer from a gamepad's left stick — the input path
/// for controller-only platforms (tvOS) and any pad-equipped desktop, since
/// the game is otherwise mouse-driven. Not part of the original (a 2000s
/// keyboard/mouse PC game); it's a native-client convenience layered on the
/// existing `SoftwareCursor` + `ScreenInputEvent` model.
///
/// The left stick moves the cursor at a velocity proportional to its
/// deflection (integrated over the frame's delta time, clamped to the
/// canvas), and the click button synthesizes a `.pointerDown` at the cursor
/// on its press edge — so every screen reacts exactly as it does to a real
/// mouse, no per-screen gamepad code.
@MainActor
public final class GamepadCursor {

    /// Cursor speed at full stick deflection, in logical pixels per second.
    public var speed: Float = 720

    /// Radial deadzone — stick magnitudes at or below this are treated as
    /// rest (analog sticks never quite center).
    public var deadzone: Float = 0.2

    /// The movement bounds (the logical canvas).
    public var bounds: (width: Float, height: Float) = (800, 600)

    /// Whether the stick moved the cursor since the last reset — lets a
    /// backend reveal the cursor only once the pad is actually used.
    public private(set) var didMove = false

    private var wasClickPressed = false

    public init() {}

    /// Advances the virtual cursor from the current left-stick vector
    /// (each component in `-1...1`, y positive downward to match screen
    /// coordinates) and click-button state, mutating `position` and returning
    /// the synthesized events to feed the state machine: a `.pointerMoved`
    /// while the stick pushes past the deadzone, and a `.pointerDown` on the
    /// click button's press edge (so holding it doesn't repeat).
    public func update(
        stickX: Float,
        stickY: Float,
        click: Bool,
        deltaTime: Double,
        position: inout (x: Float, y: Float)
    ) -> [ScreenInputEvent] {
        var events: [ScreenInputEvent] = []

        let magnitude = (stickX * stickX + stickY * stickY).squareRoot()
        if magnitude > deadzone {
            let dt = Float(deltaTime)
            position.x = min(max(0, position.x + stickX * speed * dt), bounds.width)
            position.y = min(max(0, position.y + stickY * speed * dt), bounds.height)
            didMove = true
            events.append(.pointerMoved(x: position.x, y: position.y))
        }

        if click && !wasClickPressed {
            events.append(.pointerDown(x: position.x, y: position.y))
        }
        wasClickPressed = click

        return events
    }
}
