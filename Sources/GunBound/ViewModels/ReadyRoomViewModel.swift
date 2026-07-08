import GunBoundProtocol

/// Logic for the pre-battle Ready Room (state 9). Shows the room's roster
/// (from the `JoinRoomResponse` the Game Room List stored in the session), the
/// selected map, and drives the ready/start + cancel controls. Battle/session
/// logic itself stays out of scope — "start" readies up and advances to the
/// Loading screen.
///
/// The roster is an 8-slot, 2-row × 4-column grid, matching the decompiled
/// Ready Room's roster layout (`docs/screens/09_ready_room.md`). The live 3D
/// character/avatar preview the original draws (via the battle texture family)
/// is deferred with the rest of the battle-render work.
@MainActor
public final class ReadyRoomViewModel: ScreenViewModel {
    public let backgroundImageName = "ready_selectmap.img"
    public let characterSelectImageName = "ready_selectcharacter.img"
    public let startButtonImageName = "b_ready_startgame.img"
    public let cancelButtonImageName = "b_ready_cancel.img"

    // MARK: Roster grid geometry (2 rows × 4 columns of player slots)
    public static let maxPlayers = 8
    public static let rosterColumns = 4
    static let rosterOrigin = (x: Float(40), y: Float(70))
    static let rosterSlotSize = (width: Float(175), height: Float(96))
    static let rosterSpacing = (x: Float(6), y: Float(8))

    public var startRect: Rect = .zero
    public var cancelRect: Rect = .zero

    public private(set) var isReady = false
    public private(set) var isBusy = false

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    /// The joined room's name, or empty if the room isn't known (e.g. reached
    /// via "Create" before a room exists).
    public var roomName: String { delegate.session.currentRoom?.name ?? "" }

    /// The selected map for this room.
    public var map: GameMap { delegate.session.currentRoom?.map ?? .random }

    /// The roster from the join response (up to `maxPlayers`).
    public var players: [JoinRoomResponse.PlayerSession] {
        Array((delegate.session.currentRoom?.players ?? []).prefix(Self.maxPlayers))
    }

    /// The on-screen rect of roster slot `index` (0..<`maxPlayers`).
    public func rosterSlotRect(at index: Int) -> Rect {
        let column = index % Self.rosterColumns
        let row = index / Self.rosterColumns
        return Rect(
            x: Self.rosterOrigin.x + Float(column) * (Self.rosterSlotSize.width + Self.rosterSpacing.x),
            y: Self.rosterOrigin.y + Float(row) * (Self.rosterSlotSize.height + Self.rosterSpacing.y),
            width: Self.rosterSlotSize.width,
            height: Self.rosterSlotSize.height
        )
    }

    public func onEnter() {
        isReady = false
        isBusy = false
    }

    public func onExit() {
        isBusy = false
    }

    public func update(deltaTime: Double) {}

    public func handle(_ event: ScreenInputEvent) {
        guard case .pointerDown(let x, let y) = event, !isBusy else { return }
        if cancelRect.contains(x: x, y: y) {
            cancel()
        } else if startRect.contains(x: x, y: y) {
            start()
        }
    }

    /// Leaves the room back to the lobby, clearing the session's current room.
    private func cancel() {
        delegate.session.currentRoom = nil
        delegate.requestTransition(to: .gameRoomList)
    }

    /// Readies up (opcode `0x3230`) and advances to Loading. With no live
    /// connection (e.g. reached via the lobby's "Create" button before a room
    /// exists), it just advances locally.
    private func start() {
        guard let client = delegate.client else {
            delegate.requestTransition(to: .loading)
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let response = try await client.setReady(true)
                if response.isSuccess {
                    isReady = true
                    delegate.requestTransition(to: .loading)
                } else {
                    print("[GunBound] ready request rejected")
                }
            } catch {
                print("[GunBound] couldn't set ready: \(error)")
            }
        }
    }
}
