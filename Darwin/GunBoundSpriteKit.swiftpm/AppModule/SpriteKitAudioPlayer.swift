import AVFoundation
import GunBound
import GunBoundClient

/// `ClientAudioPlayer` implemented against `AVAudioPlayer`. Unlike
/// `GunBoundSDL3`'s `SDL3AudioPlayer` (which has to detect "finished" and
/// manually restart, since the SDL3 mixer wrapper doesn't expose native
/// looping), `AVAudioPlayer.numberOfLoops` loops natively, so
/// `update(deltaTime:)` only prunes finished sound effects.
final class SpriteKitAudioPlayer: ClientAudioPlayer {
    private var player: AVAudioPlayer?
    /// One-shot sound effects still playing (pruned once finished).
    private var effects: [AVAudioPlayer] = []

    // MARK: Mute preference

    /// The `UserDefaults` key persisting the mute preference (toggled from
    /// the macOS Sound menu / the playground's Sound command menu).
    static let muteDefaultsKey = "GunBoundMuteSound"

    /// Every live player, weakly held, so a menu toggle mutes mid-playback —
    /// each screen creates its own player, and music keeps looping across
    /// the toggle rather than restarting.
    private static let registry = NSHashTable<SpriteKitAudioPlayer>.weakObjects()

    /// The persisted mute preference.
    static var isMuted: Bool {
        UserDefaults.standard.bool(forKey: muteDefaultsKey)
    }

    /// Persists the mute preference and applies it to every live player
    /// (current music and in-flight sound effects included).
    static func setMuted(_ muted: Bool) {
        UserDefaults.standard.set(muted, forKey: muteDefaultsKey)
        for player in registry.allObjects {
            player.applyVolume()
        }
    }

    init() {
        Self.registry.add(self)
    }

    private var volume: Float { Self.isMuted ? 0 : 1 }

    private func applyVolume() {
        player?.volume = volume
        for effect in effects {
            effect.volume = volume
        }
    }

    var isPlaying: Bool { player?.isPlaying ?? false }

    func play(named name: String, assets: AssetLibrary, loop: Bool) {
        do {
            let path = try assets.musicPath(named: name)
            let player = try AVAudioPlayer(contentsOf: path)
            player.numberOfLoops = loop ? -1 : 0
            player.volume = volume
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            print("[GunBoundSpriteKit] warning: couldn't play music '\(name)': \(error)")
        }
    }

    @discardableResult
    func playEffect(named name: String, assets: AssetLibrary) -> Bool {
        do {
            let path = try assets.soundPath(named: name)
            let effect = try AVAudioPlayer(contentsOf: path)
            effect.volume = volume
            effect.prepareToPlay()
            effect.play()
            effects.append(effect)
            return true
        } catch {
            return false  // callers fall back through candidate names
        }
    }

    func stop() {
        player?.stop()
        player = nil
        for effect in effects {
            effect.stop()
        }
        effects = []
    }

    func update(deltaTime: Double) {
        effects.removeAll { !$0.isPlaying }
    }
}
