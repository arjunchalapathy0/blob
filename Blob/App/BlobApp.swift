import SwiftUI

@main
enum Entry {
    static func main() {
        // `Blob --claude-hook` is called by Claude Code hooks: record the event and exit
        // without starting the UI.
        if CommandLine.arguments.contains("--claude-hook") {
            ClaudeHookCLI.run()
            exit(0)
        }
        Prefs.registerDefaults()
        BlobApp.main()
    }
}

struct BlobApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(Prefs.menuBarIcon) private var showMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra("Blob", systemImage: "capsule.fill", isInserted: $showMenuBarIcon) {
            Button("Settings…") { SettingsWindow.show() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit Blob") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
