import CSDL3
import SDL3Swift
import GunBound

/// Translates a raw SDL event into the platform-agnostic input a
/// `ScreenViewModel` expects, `nil` for anything a screen doesn't care about
/// (window resize, gamepad, etc).
///
/// Keyboard text is best-effort: the SDL wrapper exposes no text-input event,
/// so printable characters are mapped from the keycode's ASCII value (no
/// shift/layout handling — fine for room names and numbers). Return is the
/// `.activate` (confirm/submit) key; backspace and the arrows become editing
/// `.key`s; every other printable key (including space) becomes `.text`.
func translate(_ event: SDLEvent) -> ScreenInputEvent? {
    switch event {
    case .mouseButtonDown(_, let x, let y, _):
        return .pointerDown(x: x, y: y)
    case .mouseMotion(_, let x, let y, _):
        return .pointerMoved(x: x, y: y)
    case .keyDown(let scancode, let keycode):
        switch scancode.rawValue {
        case SDL_SCANCODE_RETURN.rawValue, SDL_SCANCODE_KP_ENTER.rawValue:
            return .activate
        case SDL_SCANCODE_BACKSPACE.rawValue:
            return .key(.backspace)
        case SDL_SCANCODE_LEFT.rawValue:
            return .key(.left)
        case SDL_SCANCODE_RIGHT.rawValue:
            return .key(.right)
        default:
            let code = keycode.rawValue
            if (0x20...0x7e).contains(code), let scalar = UnicodeScalar(code) {
                return .text(String(Character(scalar)))
            }
            return nil
        }
    default:
        return nil
    }
}
