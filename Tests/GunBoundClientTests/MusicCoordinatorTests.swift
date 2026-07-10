import Testing
@testable import GunBound
@testable import GunBoundClient

@Suite @MainActor
struct MusicCoordinatorTests {

    /// A minimal `ClientAudioPlayer` that records `stop()` calls and, like the
    /// real backends, releases its coordinator slot when stopped.
    private final class FakePlayer: ClientAudioPlayer {
        let coordinator: MusicCoordinator
        private(set) var stopCount = 0
        init(_ coordinator: MusicCoordinator) { self.coordinator = coordinator }

        func start() { coordinator.takeMusic(self) }

        func play(named name: String, assets: AssetLibrary, loop: Bool) {}
        func playEffect(named name: String, assets: AssetLibrary) -> Bool { false }
        var isPlaying: Bool { false }
        func update(deltaTime: Double) {}
        func stop() {
            stopCount += 1
            coordinator.release(self)
        }
    }

    @Test func startingMusicStopsThePreviousHolder() {
        let coordinator = MusicCoordinator()
        let first = FakePlayer(coordinator)
        let second = FakePlayer(coordinator)

        first.start()
        #expect(first.stopCount == 0)

        // The next screen's player claims the slot, stopping the first.
        second.start()
        #expect(first.stopCount == 1)
        #expect(second.stopCount == 0)
    }

    @Test func reclaimingTheSlotDoesNotStopSelf() {
        let coordinator = MusicCoordinator()
        let player = FakePlayer(coordinator)

        player.start()
        player.start()
        #expect(player.stopCount == 0)
    }

    @Test func releasingLeavesAnotherHoldersOwnership() {
        let coordinator = MusicCoordinator()
        let first = FakePlayer(coordinator)
        let second = FakePlayer(coordinator)

        first.start()
        second.start()          // first stopped, second owns the slot
        #expect(first.stopCount == 1)

        // First stopping again must not disturb second's ownership, so a
        // third claim only stops second.
        first.stop()
        let third = FakePlayer(coordinator)
        third.start()
        #expect(second.stopCount == 1)
    }
}
