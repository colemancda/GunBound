/// Guarantees only one background-music track ever plays at a time.
///
/// The original client keeps a *single* music object (`PlayMusicTrack`
/// compares the requested track against the one already playing and switches
/// the same object), so there's structurally no way for two tracks to
/// overlap. This port instead gives each screen its own `ClientAudioPlayer`,
/// which reopens the door to leftover music bleeding across a screen change if
/// an outgoing screen ever fails to stop its track before the next one starts.
///
/// A backend creates one coordinator and hands it to every music-capable
/// player it makes. When a player starts *music* it becomes the sole music
/// holder, and the coordinator stops whoever held that slot before — so the
/// login/lobby screen can never inherit a battle or channel loop from the
/// screen you just left. Sound effects don't register here; they're expected
/// to overlap the music and each other.
@MainActor
public final class MusicCoordinator {

    /// The player currently owning the single music slot. Weak: if the owning
    /// screen (and its player) is torn down, it clears itself.
    private weak var currentMusic: ClientAudioPlayer?

    public init() {}

    /// Makes `player` the sole music player, stopping whoever held the slot
    /// before. A no-op if `player` already holds it.
    public func takeMusic(_ player: ClientAudioPlayer) {
        if currentMusic !== player {
            // `stop()` re-enters `release(_:)`, clearing the slot before we
            // claim it below — hence the reassignment after, not before.
            currentMusic?.stop()
        }
        currentMusic = player
    }

    /// Releases the music slot if `player` still holds it (called when a
    /// player stops). Leaves another player's ownership untouched.
    public func release(_ player: ClientAudioPlayer) {
        if currentMusic === player {
            currentMusic = nil
        }
    }
}
