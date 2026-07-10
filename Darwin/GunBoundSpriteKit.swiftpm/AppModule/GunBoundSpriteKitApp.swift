import SwiftUI

@main
struct GunBoundSpriteKitApp: App {
    /// The persisted mute preference — same `UserDefaults` key the Mac app's
    /// Sound menu toggles, surfaced here as a command menu for the SwiftUI
    /// lifecycle (Swift Playgrounds / iPad).
    @AppStorage(SpriteKitAudioPlayer.muteDefaultsKey) private var isMuted = false

    var body: some Scene {
        WindowGroup {
            LoginView()
                .onChange(of: isMuted) { muted in
                    SpriteKitAudioPlayer.setMuted(muted)
                }
        }
        .commands {
            CommandMenu("Sound") {
                Toggle("Mute", isOn: $isMuted)
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
    }
}
