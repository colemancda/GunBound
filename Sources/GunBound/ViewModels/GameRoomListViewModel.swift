import GunBoundProtocol

/// Logic for the Game Room List / channel lobby (state 3) — the busiest
/// screen. On entering, it requests the channel's room list (opcode
/// `0x2100`), displays up to six rooms in a 3-row × 2-column card grid,
/// lets the player highlight one and join it (opcode `0x2110` → Ready Room
/// on success), and drives the five lobby buttons.
///
/// Grid geometry is taken from the decompiled `RenderRoomLabel`/`FUN_0042a220`
/// (`docs/screens/03_game_room_list.md`): two columns at x `0x18`/`0x144`,
/// `roomIndex/3` → column, `roomIndex%3` → row at a `0x3c` (60px) stride,
/// cards `257×58` (frames 1–3 of `gamelist_back.img`: base / highlighted /
/// joined). The room grid's vertical origin isn't given in the decomp, so
/// `gridTop` is estimated from where `gamelist_back.img`'s content region
/// begins; hit-testing and drawing share it, so interaction stays consistent
/// regardless.
@MainActor
public final class GameRoomListViewModel: ScreenViewModel {
    public struct Button: Equatable, Sendable {
        public let name: String
        public var rect: Rect = .zero
    }

    /// Waiting / in-progress / full — chooses the per-card status icon
    /// (frames 7 / 8 / 9 of `gamelist_back.img`, per the decomp).
    public enum RoomStatus: Sendable {
        case waiting
        case playing
        case full
    }

    public let backgroundImageName = "gamelist_back.img"

    // MARK: Room-card grid geometry (see the type-level doc comment)
    public static let maxVisibleRooms = 6
    public static let cardSize = (width: Float(257), height: Float(58))
    static let columnX: [Float] = [24, 324]
    static let gridTop: Float = 290
    static let rowStride: Float = 60

    public private(set) var buttons: [Button] = [
        Button(name: "gamelist_create.img"),
        Button(name: "b_gamelist_join.img"),
        Button(name: "b_gamelist_ranking.img"),
        Button(name: "b_gamelist_avatar.img"),
        Button(name: "b_gamelist_buddy.img"),
    ]

    /// Rooms from the most recent `0x2103` room-list response (capped to the
    /// six on-screen cards). Settable so tests and SwiftUI previews can
    /// populate it directly — the production path fills it from
    /// `delegate.client`, which is a concrete socket type that can't be
    /// mocked at this layer.
    public var rooms: [RoomListResponse.Room] = []

    public private(set) var hoveredButtonIndex: Int?
    public private(set) var hoveredRoomIndex: Int?
    /// The highlighted room card (`this+8` in the decomp) — set by clicking a
    /// card, joined via the Join button.
    public private(set) var selectedRoomIndex: Int?
    public private(set) var isLoadingRooms = false
    public private(set) var isJoiningRoom = false

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {
        hoveredButtonIndex = nil
        hoveredRoomIndex = nil
        selectedRoomIndex = nil
        isJoiningRoom = false
        loadRooms()
    }

    public func onExit() {
        hoveredButtonIndex = nil
        hoveredRoomIndex = nil
        selectedRoomIndex = nil
    }

    public func update(deltaTime: Double) {}

    /// The view calls this once it knows the loaded texture's size for the
    /// button at `index` (buttons are laid out left-to-right by the view;
    /// this view model only stores the resulting hit-testing rect).
    public func setRect(_ rect: Rect, forButtonAt index: Int) {
        guard buttons.indices.contains(index) else { return }
        buttons[index].rect = rect
    }

    // MARK: - Room grid

    /// Number of room cards currently visible (rooms, capped at six).
    public var visibleRoomCount: Int { min(rooms.count, Self.maxVisibleRooms) }

    /// The on-screen rect of the room card at `index` (0..<`maxVisibleRooms`).
    public func roomRect(at index: Int) -> Rect {
        let column = index / 3
        let row = index % 3
        return Rect(
            x: Self.columnX[column],
            y: Self.gridTop + Float(row) * Self.rowStride,
            width: Self.cardSize.width,
            height: Self.cardSize.height
        )
    }

    /// Status of a room, for picking its status icon.
    public func status(of room: RoomListResponse.Room) -> RoomStatus {
        if room.isPlaying { return .playing }
        return room.playerCount >= room.capacity.rawValue ? .full : .waiting
    }

    // MARK: - Input

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredRoomIndex = (0..<visibleRoomCount).first { roomRect(at: $0).contains(x: x, y: y) }
            hoveredButtonIndex = buttons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            if let roomIndex = (0..<visibleRoomCount).first(where: { roomRect(at: $0).contains(x: x, y: y) }) {
                selectedRoomIndex = roomIndex
                return
            }
            guard let index = buttons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) else { return }
            handleButton(buttons[index].name)

        case .activate:
            break
        }
    }

    private func handleButton(_ name: String) {
        print("[GunBound] clicked room-list button: \(name)")
        switch name {
        case "gamelist_create.img":
            delegate.requestTransition(to: .readyRoom)
        case "b_gamelist_join.img":
            joinSelectedRoom()
        case "b_gamelist_avatar.img":
            delegate.requestTransition(to: .avatarShop)
        default:
            break
        }
    }

    // MARK: - Networking

    /// Requests the channel room list (opcode `0x2100`) — the lobby's
    /// `OnEnter` behaviour. No-op (leaves the list empty) if there's no live
    /// connection, e.g. when the lobby was reached without a real login.
    private func loadRooms() {
        guard let client = delegate.client else { return }
        isLoadingRooms = true
        Task {
            defer { isLoadingRooms = false }
            do {
                let rooms = try await client.fetchRoomList()
                self.rooms = Array(rooms.prefix(Self.maxVisibleRooms))
                print("[GunBound] room list: \(self.rooms.count) room(s)")
            } catch {
                print("[GunBound] couldn't fetch room list: \(error)")
            }
        }
    }

    /// Joins the highlighted room (opcode `0x2110`); on a successful
    /// `JoinRoomResponse` the client transitions into the room's Ready Room.
    private func joinSelectedRoom() {
        guard !isJoiningRoom, let index = selectedRoomIndex, rooms.indices.contains(index),
              let client = delegate.client else { return }
        let room = rooms[index]
        isJoiningRoom = true
        Task {
            defer { isJoiningRoom = false }
            do {
                let response = try await client.joinRoom(room.id)
                if response.isSuccess {
                    print("[GunBound] joined room \(room.id) '\(room.name)' (\(response.players.count) player(s))")
                    delegate.session.currentRoom = response
                    delegate.requestTransition(to: .readyRoom)
                } else {
                    print("[GunBound] room join rejected for \(room.id)")
                }
            } catch {
                print("[GunBound] couldn't join room \(room.id): \(error)")
            }
        }
    }
}
