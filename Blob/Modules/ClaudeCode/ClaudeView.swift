import SwiftUI

struct ClaudeView: View {
    @EnvironmentObject private var claude: ClaudeService

    var body: some View {
        if !claude.hooksInstalled {
            EmptyState(text: "Connect Claude Code",
                       detail: "Blob adds a small hook to ~/.claude/settings.json so it can show when Claude is working, done, or waiting for you.",
                       mood: .curious, actionTitle: "Install hooks") { claude.installHooks() }
        } else if claude.sessions.isEmpty {
            EmptyState(text: "No active sessions", detail: "Start Claude Code in a terminal and it shows up here.", mood: .sleepy)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Sessions")
                    Spacer()
                    if claude.hooksNeedUpdate {
                        PillButton(title: "Update hooks", symbol: "arrow.triangle.2.circlepath") { claude.installHooks() }
                    }
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(claude.sessions) { SessionRow(session: $0) }
                    }
                    .animation(Springs.snap, value: claude.sessions)
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: ClaudeSession
    @EnvironmentObject private var claude: ClaudeService

    var body: some View {
        HStack(spacing: 12) {
            BlobCharacter(mood: mood, size: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.project).font(Theme.font(12, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(session.detail).font(Theme.font(11)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(label).font(Theme.font(10, .semibold))
                .foregroundStyle(session.state == .waiting ? Color.black : Theme.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(session.state == .waiting ? Theme.ink : Theme.fillStrong, in: Capsule())
            Text(session.updated, style: .relative)
                .font(Theme.font(10)).foregroundStyle(Theme.tertiary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button("Open Folder") { claude.openTerminal(for: session) }
            Button("Dismiss") { claude.dismiss(session) }
        }
    }

    private var mood: Mood {
        switch session.state {
        case .working: .busy
        case .waiting: .alarmed
        case .done: .happy
        case .idle: .sleepy
        }
    }

    private var label: String {
        switch session.state {
        case .working: "Working"
        case .waiting: "Needs you"
        case .done: "Done"
        case .idle: "Idle"
        }
    }
}
