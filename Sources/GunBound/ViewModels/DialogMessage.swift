/// A user-facing message for the shared error/notice dialog, identified by
/// its **localized-string id** — the port of how the original picks dialog
/// text: `ShowErrorDialog(code)` resolves `GetLocalizedString(id)` from the
/// `Language.txt` table (see the decomp's ARCHITECTURE.md "Text
/// localization"). The view-model layer names the message by id; the screen
/// (which owns the `AssetLibrary`) resolves it, falling back to `fallback`
/// when the loaded language pack lacks that id.
///
/// Both the localized text and `fallback` use the original's convention: a
/// title sentence, a blank line, then the detail body. The dialog renders
/// the whole string wrapped, putting the first line in the title strip and
/// the rest in the body (there's no separate title field — mirroring
/// `ShowErrorDialog`, which wraps one message and blits its first line into
/// the strip).
public struct DialogMessage: Equatable, Hashable, Sendable {

    /// The `Language.txt` string id (the original's `GetLocalizedString`
    /// argument) — for the error family, `code + 0xc7`.
    public let localizedID: LocalizedStringID

    /// Built-in English text used when the loaded `Language.txt` has no
    /// entry for `localizedID`. "Title\n\nBody" form.
    public let fallback: String

    public init(localizedID: LocalizedStringID, fallback: String) {
        self.localizedID = localizedID
        self.fallback = fallback
    }
}

public extension DialogMessage {

    /// id 200 — "Server access error": the requested server couldn't be
    /// reached (broker unreachable, connection refused). Fallback text is
    /// verbatim from the decomp's English `Language.txt`
    /// (GunBound-Decomp `docs/localized-strings.md`).
    static var serverAccessError: DialogMessage {
        DialogMessage(
            localizedID: .serverAccessError,
            fallback: "Server Access Error\n\nCan't access to server you required.\nPlease use other servers or try little later."
        )
    }

    /// id 201 — "Access time has expired": a network problem or the wait
    /// ran too long (our request timeout, a mid-attempt stall). Fallback is
    /// verbatim from the decomp's English `Language.txt`.
    static var accessTimeExpired: DialogMessage {
        DialogMessage(
            localizedID: .accessTimeExpired,
            fallback: "Access time has expired.\n\nEither the problem in network or waiting time were too long.\nThe connection will close automatically.\nPlease try little later."
        )
    }

    /// id 205 — "Login error": the password was wrong. Fallback verbatim
    /// from the decomp's English `Language.txt`.
    static var loginError: DialogMessage {
        DialogMessage(
            localizedID: .loginError,
            fallback: "Login Error\n\nWrong password.\nPlease check your password."
        )
    }
}
