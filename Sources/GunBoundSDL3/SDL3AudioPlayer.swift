import SDL3Swift
import SDL3Mixer
import GunBound
import GunBoundClient

/// `ClientAudioPlayer` implemented against SDL3's mixer. `SDLAudioTrack.play()`
/// always plays its audio once — the wrapper hardcodes a loop count of 0 and
/// doesn't expose a way to request looping — so continuous background music
/// is done here by detecting "finished" during `update(deltaTime:)` and
/// calling `play()` again, rather than a single native looping call.
@MainActor
final class SDL3AudioPlayer: ClientAudioPlayer {
    private let mixer: SDLMixer
    private var audio: SDLAudio?
    private var track: SDLAudioTrack?
    private var shouldLoop = false

    init(mixer: SDLMixer) {
        self.mixer = mixer
    }

    var isPlaying: Bool { track?.isPlaying ?? false }

    func play(named name: String, assets: AssetLibrary, loop: Bool) {
        shouldLoop = loop
        do {
            let path = try assets.musicPath(named: name)
            let audio = try SDLAudio(mixer: mixer, contentsOfFile: path.path)
            let track = try SDLAudioTrack(mixer: mixer)
            try track.setAudio(audio)
            try track.play()
            self.audio = audio
            self.track = track
        } catch {
            print("[GunBoundSDL3] warning: couldn't play music '\(name)': \(error)")
        }
    }

    func stop() {
        try? track?.stop()
        track = nil
        audio = nil
        shouldLoop = false
    }

    func update(deltaTime: Double) {
        guard shouldLoop, track != nil, !isPlaying else { return }
        try? track?.play()
    }
}
