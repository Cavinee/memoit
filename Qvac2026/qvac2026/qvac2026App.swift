import SwiftUI

@main
struct qvac2026App: App {
    @StateObject private var theme = ThemeStore.shared

    init() {
        _ = DatabaseService.shared
        DatabaseService.shared.notes.purgeExpiredTrash()
        #if DEBUG
        EmbeddedQVACHostStatusService.shared.startStartupProbe()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(theme.appearance.colorScheme)
                .environmentObject(theme)
        }
    }
}
