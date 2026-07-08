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

    /// A generic "confirm" input not tied to a screen position — a keypress,
    /// matching screens that advance on "press any key" regardless of where
    /// on the keyboard/screen it happened.
    case activate
}
