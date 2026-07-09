import SDL2Swift
import SDL2Mixer
import GunBound
import GunBoundClient

/// `ClientAudioPlayer` implemented against SDL2's mixer. Unlike SDL3Mixer's
/// per-track API, SDL2Mixer streams music through a single global `SDLMusic`
/// slot with native looping (`play(loops: -1)`), so no manual
/// detect-and-restart is needed the way `SDL3AudioPlayer` does.
@MainActor
final class SDL2AudioPlayer: ClientAudioPlayer {
    private var music: SDLMusic?
    /// Chunks must outlive their channel playback; a small FIFO keeps
    /// recent effects alive (channels are short one-shots, so holding the
    /// last few is enough without tracking per-channel completion).
    private var effects: [SDLAudioChunk] = []

    init() {}

    var isPlaying: Bool { SDLMusic.isPlaying }

    func play(named name: String, assets: AssetLibrary, loop: Bool) {
        do {
            let path = try assets.musicPath(named: name)
            let music = try SDLMusic(contentsOfFile: path.path)
            try music.play(loops: loop ? -1 : 0)
            self.music = music
        } catch {
            print("[GunBoundSDL2] warning: couldn't play music '\(name)': \(error)")
        }
    }

    @discardableResult
    func playEffect(named name: String, assets: AssetLibrary) -> Bool {
        do {
            let path = try assets.soundPath(named: name)
            let chunk = try SDLAudioChunk(contentsOfFile: path.path)
            try chunk.play()
            effects.append(chunk)
            if effects.count > 16 {
                effects.removeFirst(effects.count - 16)
            }
            return true
        } catch {
            return false  // callers fall back through candidate names
        }
    }

    func stop() {
        try? SDLMusic.halt()
        music = nil
        effects = []
    }

    func update(deltaTime: Double) {}
}
