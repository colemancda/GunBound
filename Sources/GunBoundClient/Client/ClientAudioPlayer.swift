/// What a screen needs from an audio backend: play a named `.mp3`/`.xes`
/// resource (optionally looping) and query/stop playback — expressed
/// abstractly so the same screen implementation works against SDL3's mixer,
/// AVFoundation (for a SpriteKit client), or any other backend.
///
/// Each screen gets its own player instance (via `ClientContext.makeAudioPlayer()`)
/// rather than sharing one globally, since screens independently start/stop
/// their own music track as they're entered/exited.
@MainActor
public protocol ClientAudioPlayer: AnyObject {
    /// Starts playing a named music resource. `loop` requests continuous
    /// looping — most audio APIs don't expose an explicit "loop forever"
    /// flag on arbitrary compressed audio, so implementations are expected
    /// to detect "finished" during `update(deltaTime:)` and restart instead
    /// of relying on a single native looping call.
    func play(named name: String, assets: AssetLibrary, loop: Bool)

    /// Stops playback and releases any loaded audio.
    func stop()

    /// Whether audio is currently playing (`false` once it finishes, or if
    /// nothing was ever started).
    var isPlaying: Bool { get }

    /// Called once per frame so looping playback can be restarted once it
    /// finishes — a no-op for backends whose audio API loops natively.
    func update(deltaTime: Double)
}
