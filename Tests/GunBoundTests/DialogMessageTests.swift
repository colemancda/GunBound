import Testing
@testable import GunBound

@Suite struct DialogMessageTests {

    /// The presets carry the decomp-confirmed `Language.txt` ids, and each
    /// fallback is `Title\n\nBody` shaped (the dialog renders the first line
    /// in the title strip).
    @Test func presetsUseTheConfirmedIds() {
        #expect(DialogMessage.serverAccessError.localizedID == .serverAccessError)
        #expect(DialogMessage.accessTimeExpired.localizedID == .accessTimeExpired)
        #expect(DialogMessage.loginError.localizedID == .loginError)

        let expired = DialogMessage.accessTimeExpired.fallback
        #expect(expired.hasPrefix("Access time has expired.\n\n"))
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
