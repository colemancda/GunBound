import CSDL3
import SDL3Swift
import SDL3Mixer
import GunBound

/// Shared behavior for the simple, mostly-static screens (Logo, Title,
/// Server Select, Game Room List): load a background `.img` (plus optional
/// button `.img`s) and a looping/one-shot `.mp3`, draw them full-window, and
/// let a subclass decide when/how to transition onward.
///
/// Resource loads are best-effort: a missing entry (this repo's sample
/// `graphics.xfs`/`sound.xfs` don't perfectly match every filename the
/// decomp docs list — e.g. `logomode.img` isn't present in this archive,
/// only `logomode2.img`) is logged and skipped rather than crashing the
/// client, since the goal of this pass is proving the pipeline end-to-end,
/// not requiring a byte-perfect asset set.
@MainActor
class ImageBackgroundScreen: GameScreen {
    private let backgroundImageName: String
    private let musicName: String?
    /// Whether `updateMusicLoop()` should restart the track once it finishes
    /// playing. `SDLAudioTrack.play()` always plays its audio once (the
    /// underlying wrapper hardcodes a loop count of 0, and doesn't expose a
    /// way to request looping), so continuous background music is done here
    /// by detecting "finished" and calling `play()` again, rather than a
    /// single native looping playback call.
    private let loopMusic: Bool
    private(set) var backgroundTexture: SDLTexture?
    private var music: SDLAudio?
    private var track: SDLAudioTrack?

    /// `true` once a music track was successfully started for this screen;
    /// `false` if there's no music configured or it failed to load — lets
    /// subclasses (e.g. `TitleScreen`) distinguish "still playing" from
    /// "never started" when deciding whether to wait on `isMusicPlaying`.
    var didStartMusic: Bool { track != nil }

    /// Whether the screen's music track is still playing. `false` once it
    /// finishes (or if no track ever started).
    var isMusicPlaying: Bool { track?.isPlaying ?? false }

    init(backgroundImageName: String, musicName: String?, loopMusic: Bool = false) {
        self.backgroundImageName = backgroundImageName
        self.musicName = musicName
        self.loopMusic = loopMusic
    }

    func onEnter(context: ScreenContext) throws {
        backgroundTexture = loadTexture(named: backgroundImageName, context: context)
        if let musicName {
            playMusic(named: musicName, context: context)
        }
    }

    func onExit() {
        try? track?.stop()
        track = nil
        music = nil
        backgroundTexture = nil
    }

    func handleEvent(_ event: SDLEvent, context: ScreenContext) {}

    func update(deltaTime: Double, context: ScreenContext) {
        updateMusicLoop()
    }

    /// Restarts the music track once it finishes, if `loopMusic` was
    /// requested. Subclasses that override `update(deltaTime:context:)`
    /// entirely (e.g. `TitleScreen`, which wants "did it finish" as a
    /// one-shot signal rather than continuous looping) should call this
    /// themselves if they also want looping — none currently do.
    func updateMusicLoop() {
        guard loopMusic, didStartMusic, !isMusicPlaying else { return }
        try? track?.play()
    }

    /// Clears the window and draws the background — subclasses call this
    /// first, then draw anything else on top. Presenting is the main loop's
    /// job (`GameStateMachine.render()`), done once per frame after every
    /// screen has drawn, not per-screen.
    func render(_ renderer: SDLRenderer) throws {
        try renderer.setDrawColor(red: 0, green: 0, blue: 0)
        try renderer.clear()
        if let backgroundTexture {
            let attributes = try backgroundTexture.attributes()
            try renderer.copy(
                backgroundTexture,
                destination: SDL_FRect(x: 0, y: 0, w: Float(attributes.width), h: Float(attributes.height))
            )
        }
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

    private func playMusic(named name: String, context: ScreenContext) {
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
}
