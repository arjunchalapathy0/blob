import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var hud: SystemHUDService
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var calendar: CalendarService
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var nowPlaying: NowPlayingService

    @AppStorage(Prefs.openOnHover) private var openOnHover = true
    @AppStorage(Prefs.hoverDelay) private var hoverDelay = 0.3
    @AppStorage(Prefs.haptics) private var haptics = true
    @AppStorage(Prefs.allDisplays) private var allDisplays = false
    @AppStorage(Prefs.overFullScreen) private var overFullScreen = false
    @AppStorage(Prefs.menuBarIcon) private var menuBarIcon = true
    @AppStorage(Prefs.replaceHUD) private var replaceHUD = true
    @AppStorage(Prefs.monochromeArtwork) private var monoArt = false
    @AppStorage(Prefs.claudeSounds) private var claudeSounds = true
    @AppStorage(Prefs.chargingNotice) private var chargingNotice = true
    @AppStorage(Prefs.timerSound) private var timerSound = true

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    BlobCharacter(mood: .happy, size: 30)
                        .padding(8)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blob").font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text("A soft little notch.").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Behavior") {
                Toggle("Open on hover", isOn: $openOnHover)
                if openOnHover {
                    LabeledContent("Hover delay") {
                        Slider(value: $hoverDelay, in: 0.05...1.0) { EmptyView() }
                            .frame(width: 180)
                        Text("\(Int(hoverDelay * 1000)) ms").monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Toggle("Haptic feedback", isOn: $haptics)
                Toggle("Show on all displays", isOn: $allDisplays)
                Toggle("Show over full-screen apps", isOn: $overFullScreen)
                Toggle("Menu bar icon", isOn: $menuBarIcon)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.secondary) }
            }

            Section("Modules") {
                ForEach(ModuleID.allCases) { ModuleToggle(module: $0) }
            }

            Section {
                Toggle("Replace volume and brightness HUD", isOn: $replaceHUD)
                PermissionRow(title: "Accessibility", granted: hud.isTrusted,
                              detail: "Needed to catch the volume and brightness keys.") {
                    hud.requestAccess()
                    hud.openAccessibilitySettings()
                }
            } header: {
                Text("System HUD")
            } footer: {
                Text(hud.isActive ? "Blob is handling media keys." : "The macOS HUD is in use.")
            }

            Section("Now Playing") {
                Toggle("Monochrome artwork", isOn: $monoArt)
                LabeledContent("Source", value: nowPlaying.backendName)
            }

            Section {
                LabeledContent("Hooks") {
                    if claude.hooksInstalled {
                        HStack {
                            Text(claude.hooksNeedUpdate ? "Out of date" : "Installed").foregroundStyle(.secondary)
                            if claude.hooksNeedUpdate { Button("Update") { claude.installHooks() } }
                            Button("Remove") { claude.uninstallHooks() }
                        }
                    } else {
                        Button("Install") { claude.installHooks() }
                    }
                }
                Toggle("Sounds when Claude finishes or needs you", isOn: $claudeSounds)
                if let error = claude.lastError { Text(error).font(.caption).foregroundStyle(.secondary) }
            } header: {
                Text("Claude Code")
            } footer: {
                Text("Adds a hook to ~/.claude/settings.json that runs Blob with --claude-hook. A backup is saved next to it.")
            }

            Section("Notices") {
                Toggle("Show when charger connects", isOn: $chargingNotice)
                Toggle("Timer sound", isOn: $timerSound)
            }

            Section("Permissions") {
                PermissionRow(title: "Calendar", granted: calendar.isAuthorized,
                              detail: "Shows upcoming events.") { calendar.requestAccess() }
                PermissionRow(title: "Camera", granted: camera.status == .authorized,
                              detail: "Only used by the Mirror tab.") { camera.requestAccess() }
            }

            Section {
                HStack {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Quit Blob") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
        .onAppear { claude.refreshInstallState() }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct ModuleToggle: View {
    let module: ModuleID
    @AppStorage private var enabled: Bool

    init(module: ModuleID) {
        self.module = module
        _enabled = AppStorage(wrappedValue: true, module.prefKey)
    }

    var body: some View {
        Toggle(isOn: $enabled) {
            Label(module.title, systemImage: module.symbol)
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let granted: Bool
    let detail: String
    let request: () -> Void

    var body: some View {
        LabeledContent {
            if granted {
                Label("Allowed", systemImage: "checkmark").labelStyle(.titleAndIcon).foregroundStyle(.secondary)
            } else {
                Button("Allow…", action: request)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}
