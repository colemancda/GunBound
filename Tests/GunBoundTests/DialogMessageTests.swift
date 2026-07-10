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
        #expect(DialogMessage.serverAccessError.localizedID == 200)
        #expect(DialogMessage.accessTimeExpired.localizedID == 201)
        #expect(DialogMessage.loginError.localizedID == 205)
        // Each fallback is itself title+body shaped.
        let (title, _) = DialogMessage.split(DialogMessage.accessTimeExpired.fallback)
        #expect(title == "Access time has expired.")
    }
}
