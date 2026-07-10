/// A localized UI-string id — the key into the original's `Language.txt`
/// table that `GetLocalizedString(id)` resolves against (see GunBound-Decomp's
/// ARCHITECTURE.md "Text localization" and `docs/localized-strings.md`). A
/// `RawRepresentable` struct rather than an enum so any id round-trips: the
/// table is sparse (the reference English build defines ids 200–247, the
/// error/message-dialog family), and only the ones we reference are named.
///
/// The screen resolves an id to text via `AssetLibrary.localizedString(_:)`;
/// the id space itself lives here in the view-model layer because
/// `DialogMessage` names messages by id (and `GunBound` doesn't depend on the
/// file-format library that parses `Language.txt`).
public struct LocalizedStringID: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The error/message-dialog family is addressed by an error `code`; the
    /// original resolves its string at `code + 0xc7` (the family begins at
    /// id 199). Use this for a dialog whose code has no named constant.
    public static func errorDialog(code: Int) -> LocalizedStringID {
        LocalizedStringID(rawValue: code + 0xc7)
    }

    // The named error/message-dialog strings, from the reference English
    // build. Comment shows `id / code` (code = id − 0xc7).

    /// id 200 / code 1 — the requested server can't be reached.
    public static let serverAccessError = LocalizedStringID(rawValue: 200)
    /// id 201 / code 2 — a network problem, or the wait ran too long.
    public static let accessTimeExpired = LocalizedStringID(rawValue: 201)
    /// id 205 / code 6 — wrong password.
    public static let loginError = LocalizedStringID(rawValue: 205)
    /// id 208 / code 9 — the client's internal data was altered.
    public static let internalDataError = LocalizedStringID(rawValue: 208)
    /// id 209 / code 10 — the channel is full.
    public static let channelAccessError = LocalizedStringID(rawValue: 209)
    /// id 212 / code 13 — the game room is full.
    public static let gameRoomAccessError = LocalizedStringID(rawValue: 212)
    /// id 213 / code 14 — the game room couldn't be created.
    public static let gameRoomCreationError = LocalizedStringID(rawValue: 213)
    /// id 215 / code 16 — the room is in a match; can't enter.
    public static let gameRoomBlocked = LocalizedStringID(rawValue: 215)
    /// id 216 / code 17 — not ready to start the match yet.
    public static let gameStartError = LocalizedStringID(rawValue: 216)
    /// id 220 / code 21 — client/server version mismatch.
    public static let versionError = LocalizedStringID(rawValue: 220)
    /// id 226 / code 27 — not enough gold or cash for the purchase.
    public static let buyError = LocalizedStringID(rawValue: 226)
}
