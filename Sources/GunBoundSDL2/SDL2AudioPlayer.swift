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

    func stop() {
        try? SDLMusic.halt()
        music = nil
    }

    func update(deltaTime: Double) {}
}
