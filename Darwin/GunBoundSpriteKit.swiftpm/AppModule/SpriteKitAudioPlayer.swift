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

    var isPlaying: Bool { player?.isPlaying ?? false }

    func play(named name: String, assets: AssetLibrary, loop: Bool) {
        do {
            let path = try assets.musicPath(named: name)
            let player = try AVAudioPlayer(contentsOf: path)
            player.numberOfLoops = loop ? -1 : 0
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
