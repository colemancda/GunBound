import CSDL3
import SDL3Swift
import SDL3Mixer
import GunBound

/// Shared SDL-side rendering/audio helpers for screens: loads a background
/// `.img` into a texture and optionally plays a `.mp3` (with manual-loop
/// support, since `SDLAudioTrack.play()` always plays once — the wrapper
/// hardcodes a loop count of 0 and doesn't expose a way to request looping).
/// Screens own one of these for composition, alongside their own
/// `ScreenViewModel` (in the `GunBound` module) which holds the actual
/// navigation/business logic and state — this type only ever deals in
/// textures/audio handles, never anything screen-logic-shaped.
@MainActor
final class ScreenRenderHelper {
    private(set) var backgroundTexture: SDLTexture?
    private var music: SDLAudio?
    private var track: SDLAudioTrack?

    var isMusicPlaying: Bool { track?.isPlaying ?? false }
    var didStartMusic: Bool { track != nil }

    func loadBackground(named name: String, context: ScreenContext) {
        backgroundTexture = loadTexture(named: name, context: context)
    }

    func unloadBackground() {
        backgroundTexture = nil
    }

    func playMusic(named name: String, context: ScreenContext) {
        do {
            let path = try context.assets.musicPath(named: name)
            let audio = try SDLAudio(mixer: context.mixer, contentsOfFile: path.path)
            let track = try SDLAudioTrack(mixer: context.mixer)
            try track.setAudio(audio)
            try track.play()
            self.music = audio
            self.track = track
        } catch {
            print("[GunBoundClient] warning: couldn't play music '\(name)': \(error)")
        }
    }

    func stopMusic() {
        try? track?.stop()
        track = nil
        music = nil
    }

    /// Restarts the music track once it finishes — call each frame from
    /// screens whose view model wants continuous looping.
    func updateMusicLoop() {
        guard didStartMusic, !isMusicPlaying else { return }
        try? track?.play()
    }

    func loadTexture(named name: String, context: ScreenContext) -> SDLTexture? {
        do {
            let frame = try context.assets.firstImageFrame(named: name)
            return try FrameTexture.make(renderer: context.renderer, frame: frame)
        } catch {
            print("[GunBoundClient] warning: couldn't load image '\(name)': \(error)")
            return nil
        }
    }

    /// Clears the window and draws the background — screens call this
    /// first, then draw anything else on top. Presenting is the main loop's
    /// job (`GameStateMachine.render()`), done once per frame after every
    /// screen has drawn, not per-screen.
    func clearAndDrawBackground(_ renderer: SDLRenderer) throws {
        try renderer.setDrawColor(red: 0, green: 0, blue: 0)
        try renderer.clear()
        if let backgroundTexture {
            try renderer.copy(backgroundTexture, destination: nativeRect(of: backgroundTexture))
        }
    }
}

/// Translates a raw SDL event into the platform-agnostic input a
/// `ScreenViewModel` expects.
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

/// A texture's native size as an `SDL_FRect` positioned at the origin — the
/// common case for full-window backgrounds/overlays.
func nativeRect(of texture: SDLTexture) -> SDL_FRect {
    let (width, height) = size(of: texture)
    return SDL_FRect(x: 0, y: 0, w: width, h: height)
}

/// A texture's pixel size, `(0, 0)` if unavailable.
func size(of texture: SDLTexture?) -> (width: Float, height: Float) {
    guard let texture, let attributes = try? texture.attributes() else { return (0, 0) }
    return (Float(attributes.width), Float(attributes.height))
}

/// Converts a view model's platform-agnostic `Rect` into an `SDL_FRect`.
func sdlRect(_ rect: Rect) -> SDL_FRect {
    SDL_FRect(x: rect.x, y: rect.y, w: rect.width, h: rect.height)
}
