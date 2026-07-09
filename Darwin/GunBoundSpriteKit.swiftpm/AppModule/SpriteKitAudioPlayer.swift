import AVFoundation
import GunBound
import GunBoundClient

/// `ClientAudioPlayer` implemented against `AVAudioPlayer`. Unlike
/// `GunBoundSDL3`'s `SDL3AudioPlayer` (which has to detect "finished" and
/// manually restart, since the SDL3 mixer wrapper doesn't expose native
/// looping), `AVAudioPlayer.numberOfLoops` loops natively, so `update(deltaTime:)`
/// has nothing to do.
final class SpriteKitAudioPlayer: ClientAudioPlayer {
    private var player: AVAudioPlayer?

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

    func stop() {
        player?.stop()
        player = nil
    }

    func update(deltaTime: Double) {}
}
