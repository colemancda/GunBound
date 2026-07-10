import Testing
@testable import GunBound

@Suite struct DialogMessageTests {

    /// The message splits into title + body on the first blank line, the way
    /// the original stores one localized entry (`title\n\ndetail`).
    @Test func splitsTitleFromBodyOnTheBlankLine() {
        let (title, body) = DialogMessage.split(
            "Access time has expired.\n\nEither the problem in network or waiting time were too long.\nPlease try little later."
        )
        #expect(title == "Access time has expired.")
        #expect(body == "Either the problem in network or waiting time were too long.\nPlease try little later.")
    }

    /// With no blank line the whole string is the body (empty title).
    @Test func noBlankLineIsAllBody() {
        let (title, body) = DialogMessage.split("Wrong password.")
        #expect(title == "")
        #expect(body == "Wrong password.")
    }

    /// The presets carry the decomp-confirmed `Language.txt` ids.
    @Test func presetsUseTheConfirmedIds() {
        #expect(DialogMessage.serverAccessError.localizedID == .serverAccessError)
        #expect(DialogMessage.accessTimeExpired.localizedID == .accessTimeExpired)
        #expect(DialogMessage.loginError.localizedID == .loginError)
        // Each fallback is itself title+body shaped.
        let (title, _) = DialogMessage.split(DialogMessage.accessTimeExpired.fallback)
        #expect(title == "Access time has expired.")
    }
}

@Suite struct LocalizedStringIDTests {

    /// The named constants carry the decomp's `Language.txt` ids, and the
    /// error-dialog factory follows the original's `code + 0xc7` mapping.
    @Test func constantsAndErrorCodeMapping() {
        #expect(LocalizedStringID.serverAccessError.rawValue == 200)
        #expect(LocalizedStringID.accessTimeExpired.rawValue == 201)
        #expect(LocalizedStringID.loginError.rawValue == 205)
        #expect(LocalizedStringID.versionError.rawValue == 220)

        // The family is `code + 0xc7`: code 1 -> 200, code 2 -> 201.
        #expect(LocalizedStringID.errorDialog(code: 1) == .serverAccessError)
        #expect(LocalizedStringID.errorDialog(code: 2) == .accessTimeExpired)
        // An unnamed id still round-trips through the raw value.
        #expect(LocalizedStringID(rawValue: 999).rawValue == 999)
    }
}
