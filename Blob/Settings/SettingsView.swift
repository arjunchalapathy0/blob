import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var hud: SystemHUDService
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var calendar: CalendarService
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var nowPlaying: NowPlayingService
    @EnvironmentObject private var updates: UpdateService
    @EnvironmentObject private var ask: AskService
    @EnvironmentObject private var lock: LockService
    @EnvironmentObject private var phoneBridge: PhoneBridge
    @EnvironmentObject private var agent: AgentService

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
    @AppStorage(Prefs.stayOpen) private var stayOpen = false
    @AppStorage(Prefs.requireAuth) private var requireAuth = false
    @AppStorage(Prefs.faceUnlock) private var faceUnlock = false
    @AppStorage(Prefs.phoneBridge) private var phoneBridgeOn = false
    @AppStorage(Prefs.voiceKey) private var voiceKey = true
    @AppStorage(Prefs.phoneTasks) private var phoneTasks = true

    @State private var appIcon = AppIconChoice.current
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var apiKey = ""
    @State private var pane: Pane = .general

    private enum Pane: String, CaseIterable, Identifiable {
        case general, modules, ask, claude, privacy, updates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: "General"
            case .modules: "Modules"
            case .ask: "Ask & voice"
            case .claude: "Claude Code"
            case .privacy: "Privacy"
            case .updates: "Updates"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .modules: "square.grid.2x2"
            case .ask: "waveform"
            case .claude: "sparkle"
            case .privacy: "lock"
            case .updates: "arrow.down.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch pane {
                case .general: generalPane
                case .modules: modulesPane
                case .ask: askPane
                case .claude: claudePane
                case .privacy: privacyPane
                case .updates: updatesPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 540)
        .onAppear {
            claude.refreshInstallState()
            ask.refreshPermissions()
        }
    }

    /// The sections of Settings, listed down the left like System Settings.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                BlobCharacter(mood: .happy, size: 22)
                    .padding(6)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Blob").font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 14)

            ForEach(Pane.allCases) { item in
                Button { pane = item } label: {
                    Label(item.title, systemImage: item.symbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(pane == item ? Color.primary.opacity(0.1) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(pane == item ? .isSelected : [])
            }

            Spacer()
            Button("Quit Blob") { NSApp.terminate(nil) }
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
        .frame(width: 190)
    }

    private var generalPane: some View {
        Form {
            Section("App icon") {
                HStack(spacing: 18) {
                    ForEach(AppIconChoice.allCases) { choice in
                        Button {
                            appIcon = choice
                            AppIconChoice.select(choice)
                        } label: {
                            VStack(spacing: 6) {
                                Image(choice.previewImage).resizable().frame(width: 64, height: 64)
                                    .padding(4)
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(appIcon == choice ? Color.accentColor : .clear, lineWidth: 2))
                                Text(choice.title).font(.caption)
                                    .foregroundStyle(appIcon == choice ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
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
                Toggle("Stay open when the cursor leaves", isOn: $stayOpen)
                Toggle("Haptic feedback", isOn: $haptics)
                Toggle("Show on all displays", isOn: $allDisplays)
                Toggle("Show over full-screen apps", isOn: $overFullScreen)
                Toggle("Menu bar icon", isOn: $menuBarIcon)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.secondary) }
            }

            Section("Notices") {
                Toggle("Show when charger connects", isOn: $chargingNotice)
                Toggle("Timer sound", isOn: $timerSound)
            }
        }
        .formStyle(.grouped)
    }

    private var modulesPane: some View {
        Form {
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
        }
        .formStyle(.grouped)
    }

    private var askPane: some View {
        Form {
            Section {
                Toggle("Hold right ⌥ to talk to Blob", isOn: $voiceKey)
                PermissionRow(title: "Microphone", granted: agent.micAllowed,
                              detail: "Only records while you hold the key.") { agent.requestMic() }
                LabeledContent("Speech (Whisper, on this Mac)") {
                    HStack {
                        Text(agent.whisperStatus).foregroundStyle(.secondary).lineLimit(1)
                        if agent.whisperStatus != "Ready" {
                            Button("Get ready") { Task { await agent.warmUp() } }
                        }
                    }
                }
                LabeledContent("Does things with") {
                    Text(ask.usesSubscription ? "Claude Code (your subscription)" : "Claude Code isn’t installed")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Voice & agent")
            } footer: {
                Text("Blob can run commands, control apps and look at your screen to do what you ask. It stops and asks before deleting, sending or buying anything, and never uses sudo. Accessibility access is needed for the key.")
            }

            Section {
                LabeledContent("Answers with") {
                    Text(ask.usesSubscription ? "Your Claude subscription (Claude Code)"
                         : ask.hasKey ? "API key" : "Not set up")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("API key (optional)") {
                    HStack {
                        SecureField(ask.hasKey ? "Saved in Keychain" : "sk-ant-…", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        Button(apiKey.isEmpty && ask.hasKey ? "Remove" : "Save") {
                            ask.setKey(apiKey)
                            apiKey = ""
                        }
                        .disabled(apiKey.isEmpty && !ask.hasKey)
                    }
                }
                PermissionRow(title: "Screen Recording", granted: ask.canCapture,
                              detail: "Only used when you ask a question.") { ask.requestScreenAccess() }
            } header: {
                Text("Ask")
            } footer: {
                Text("Ask sends a screenshot of your screen (without Blob) and your question to Claude. With Claude Code installed and signed in, it uses your Claude subscription. Questions count toward your plan's usage. Otherwise it uses an API key.")
            }
        }
        .formStyle(.grouped)
    }

    private var claudePane: some View {
        Form {
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
                Toggle("Show on iPhone (same Wi-Fi)", isOn: $phoneBridgeOn)
                if phoneBridgeOn {
                    LabeledContent("iPhone pairing code") {
                        HStack {
                            Text(phoneBridge.pairingCode).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            if phoneBridge.pairedCount > 0 {
                                Text("· \(phoneBridge.pairedCount) connected").foregroundStyle(.secondary)
                            }
                            Button("New code") { phoneBridge.resetCode() }
                        }
                    }
                    Toggle("Let iPhone ask this Mac to do things", isOn: $phoneTasks)
                }
                if let error = claude.lastError { Text(error).font(.caption).foregroundStyle(.secondary) }
            } header: {
                Text("Claude Code")
            } footer: {
                Text("Adds a hook to ~/.claude/settings.json that runs Blob with --claude-hook. A backup is saved next to it.")
            }
        }
        .formStyle(.grouped)
    }

    private var privacyPane: some View {
        Form {
            Section {
                Toggle("Require \(lock.biometryName) for Clipboard, Shelf and Ask", isOn: $requireAuth)
                    .onChange(of: requireAuth) { _, _ in lock.lock() }
                if requireAuth {
                    Toggle("Also unlock with my face (camera)", isOn: $faceUnlock)
                        .disabled(!lock.faceEnrolled)
                    LabeledContent("Face") {
                        HStack {
                            Text(lock.faceStatus ?? (lock.faceEnrolled ? "Set up" : "Not set up"))
                                .foregroundStyle(.secondary).lineLimit(2)
                            if lock.faceEnrolled {
                                Button("Forget") { lock.forgetFace() }
                            }
                            Button(lock.faceEnrolled ? "Redo" : "Set up…") { lock.setUpFace() }
                                .disabled(lock.isScanningFace)
                        }
                    }
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Locks again 30 seconds after the notch closes, and whenever your Mac locks. Face unlock uses the camera to check it’s you and that you blink. It’s a convenience, not Face ID: a video of you could fool it, so \(lock.biometryName) always works too. Your face is saved only as a fingerprint on this Mac.")
            }

            Section {
                PermissionRow(title: "Accessibility", granted: hud.isTrusted,
                              detail: "For the ⌥ key, and the volume and brightness keys.") {
                    hud.requestAccess()
                    hud.openAccessibilitySettings()
                }
                PermissionRow(title: "Microphone", granted: agent.micAllowed,
                              detail: "Only records while you hold the key.") { agent.requestMic() }
                PermissionRow(title: "Screen Recording", granted: ask.canCapture,
                              detail: "Only used when you ask about your screen.") { ask.requestScreenAccess() }
                PermissionRow(title: "Calendar", granted: calendar.isAuthorized,
                              detail: "Shows upcoming events.") { calendar.requestAccess() }
                PermissionRow(title: "Camera", granted: camera.status == .authorized,
                              detail: "Only used by the Mirror tab and face unlock.") { camera.requestAccess() }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Everything Blob is allowed to use on this Mac, in one place.")
            }
        }
        .formStyle(.grouped)
    }

    private var updatesPane: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    HStack {
                        Text(updateStatus).foregroundStyle(.secondary).lineLimit(2)
                        if updates.isAvailable {
                            Button("Update") { updates.update() }.keyboardShortcut(.defaultAction)
                        } else {
                            Button("Check now") { Task { await updates.check() } }
                                .disabled(updates.isUpdating || updates.state == .checking)
                        }
                    }
                }
                if !updates.updatesFromWeb {
                LabeledContent("iPhone") {
                    HStack {
                        Text(updates.phoneStatus ?? "Plug in or same Wi-Fi").foregroundStyle(.secondary).lineLimit(1)
                        Button(updates.isUpdatingPhone ? "Installing…" : "Update iPhone") { updates.updatePhone() }
                            .disabled(updates.isUpdatingPhone)
                    }
                }
                LabeledContent("Source folder") {
                    HStack {
                        Text(updates.sourceURL?.path ?? "Not set")
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                        Button("Change…") { chooseSource() }
                    }
                }
                }
            } header: {
                Text("Updates")
            } footer: {
                if updates.updatesFromWeb {
                    Text("Update downloads the latest Blob from blobnotch.app and relaunches it.")
                } else {
                    Text("Update pulls the latest code into the source folder, rebuilds Blob with Xcode, and relaunches it. Your permissions carry over.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updateStatus: String {
        switch updates.state {
        case .idle: return "Not checked yet"
        case .checking: return "Checking…"
        case .upToDate: return "Up to date"
        case .available(let count, let summary):
            if updates.updatesFromWeb { return summary }
            return "\(count) new change\(count == 1 ? "" : "s")" + (summary.isEmpty ? "" : ": \(summary)")
        case .updating: return updates.updatesFromWeb ? "Downloading…" : "Building the new version…"
        case .failed(let message): return message
        }
    }

    private func chooseSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use Folder"
        panel.message = "Choose the blob folder (the one with project.yml and scripts/)."
        if panel.runModal() == .OK, let url = panel.url { updates.setSource(url) }
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
