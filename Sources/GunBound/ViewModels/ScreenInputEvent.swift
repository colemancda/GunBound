/// A platform-agnostic input event, translated by a view from whatever
/// windowing/input framework it uses (e.g. SDL's `SDLEvent`) before handing
/// it to a `ScreenViewModel` — keeps view model hit-testing/navigation logic
/// independent of any specific input library.
public enum ScreenInputEvent: Equatable, Sendable {
    /// A pointer (mouse click/tap) went down at this position, in the same
    /// coordinate space as the `Rect`s the view model was given.
    case pointerDown(x: Float, y: Float)

    /// The pointer moved to this position (used for hover state).
    case pointerMoved(x: Float, y: Float)

    /// A generic "confirm" input not tied to a screen position — Enter/Space
    /// or a tap, matching screens that advance on "press any key" and doubling
    /// as the submit key for a focused text field.
    case activate

    /// Committed printable text (usually one character) for text-entry
    /// widgets. On SDL this is a best-effort ASCII mapping from the keycode
    /// (the SDL wrapper exposes no text-input event); macOS SpriteKit passes
    /// through `NSEvent` characters.
    case text(String)

    /// A non-character editing/navigation key for text widgets. Enter is *not*
    /// here — it stays `.activate` (submit/advance).
    case key(Key)

    /// A mouse-wheel/trackpad scroll at the pointer position, in whole line
    /// steps — **positive steps scroll down** (toward later content). The
    /// backend accumulates fractional trackpad deltas into steps. (The
    /// original client had no wheel handling; this is a native-client
    /// convenience routed to whatever scroll region is under the pointer.)
    case scroll(x: Float, y: Float, steps: Int)

    public enum Key: Equatable, Sendable {
        case backspace
        case left
        case right
        /// ▲/▼ — no text-editing role; in battle they adjust the aim
        /// elevation (the original's control scheme: arrows ◀/▶ walk the
        /// mobile, ▲/▼ move the barrel).
        case up
        case down
        /// Tab — cycles the weapon slot in battle (the original's weapon
        /// switch; the three slots play `b_play_weapon1/2/3` cues).
        case tab
    }
}
