import AppKit
import SwiftUI

/// First run: who Blob is, and the three things it needs before it can help.
/// Shown in the open notch in place of the tabs until it's dismissed.
struct WelcomeView: View {
    let done: () -> Void
    @EnvironmentObject private var hud: SystemHUDService
    @EnvironmentObject private var agent: AgentService
    @EnvironmentObject private var ask: AskService

    private var allSet: Bool { hud.isTrusted && agent.micAllowed && ask.usesSubscription }

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                BlobCharacter(mood: allSet ? .happy : .curious, size: 34)
                Text("Hi, I’m Blob.")
                    .font(Theme.font(17, .semibold)).foregroundStyle(Theme.ink)
                Text("I live up here. Hover to open me, or hold right ⌥ and tell me what to do.")
                    .font(Theme.font(11.5)).foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 214, alignment: .leading)

            VStack(spacing: 4) {
                WelcomeRow(symbol: "hand.raised.fill", title: "Accessibility",
                           detail: "For the ⌥ key and the volume keys.",
                           ready: hud.isTrusted, actionTitle: "Allow") {
                    hud.requestAccess()
                    hud.openAccessibilitySettings()
                }
                WelcomeRow(symbol: "mic.fill", title: "Microphone",
                           detail: "Only records while you hold the key.",
                           ready: agent.micAllowed, actionTitle: "Allow") {
                    agent.requestMic()
                }
                WelcomeRow(symbol: "sparkle", title: "Claude Code",
                           detail: "Lets me do things, on your own Claude plan.",
                           ready: ask.usesSubscription, actionTitle: "Get it") {
                    if let url = URL(string: "https://claude.com/claude-code") { NSWorkspace.shared.open(url) }
                }
                HStack {
                    Text("All of this is in Settings too.")
                        .font(Theme.font(10.5)).foregroundStyle(Theme.tertiary)
                    Spacer()
                    PillButton(title: allSet ? "Let’s go" : "Later", prominent: true, action: done)
                }
                .padding(.top, 4)
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Notice when Claude Code gets installed while this is showing.
            while !Task.isCancelled {
                ask.refreshPermissions()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }
}

private struct WelcomeRow: View {
    let symbol: String
    let title: String
    let detail: String
    let ready: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ready ? "checkmark.circle.fill" : symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ready ? Theme.ink : Theme.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(Theme.font(12, .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.font(10.5)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if ready {
                Text("Ready").font(Theme.font(10.5, .semibold)).foregroundStyle(Theme.tertiary)
            } else {
                PillButton(title: actionTitle, action: action)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(Springs.snap, value: ready)
    }
}
