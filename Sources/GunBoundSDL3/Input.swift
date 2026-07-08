import SDL3Swift
import GunBound

/// Translates a raw SDL event into the platform-agnostic input a
/// `ScreenViewModel` expects, `nil` for anything a screen doesn't care about
/// (window resize, gamepad, etc).
func translate(_ event: SDLEvent) -> ScreenInputEvent? {
    switch event {
    case .mouseButtonDown(_, let x, let y, _):
        return .pointerDown(x: x, y: y)
    case .mouseMotion(_, let x, let y, _):
        return .pointerMoved(x: x, y: y)
    case .keyDown:
        return .activate
    default:
        return nil
    }
}
