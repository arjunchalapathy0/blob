import SwiftUI

/// The first tab: Blob itself. Shows how things are, and sends requests to your Mac.
struct HomeScreen: View {
    @EnvironmentObject private var link: MacLink
    @EnvironmentObject private var timers: TimerStore
    @EnvironmentObject private var mac: MacTaskModel
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                commandCard
                statusRows
                quickTimers
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: mac.finishedCount)
    }

    private var mood: Mood {
        if mac.isBusy { return .busy }
        if link.sessions.contains(where: { $0.state == "waiting" }) { return .alarmed }
        if link.sessions.contains(where: { $0.state == "working" }) { return .busy }
        if !timers.timers.isEmpty { return .happy }
        return link.isConnected ? .idle : .sleepy
    }

    private var hero: some View {
        VStack(spacing: 10) {
            BlobCharacter(mood: mood, size: 64)
                .padding(.top, 24)
            Text(greeting).font(Theme.font(15, .semibold)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var greeting: String {
        if mac.isBusy { return "On it…" }
        if !link.isConnected { return "Looking for your Mac" }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    private var commandCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField(link.isConnected ? "Tell your Mac what to do…" : "Pair with your Mac in the Claude tab",
                          text: $mac.text, axis: .vertical)
                    .font(Theme.font(16)).foregroundStyle(Theme.ink)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { mac.send() }
                    .disabled(!link.isConnected)
                if mac.isBusy {
                    IconButton(symbol: "stop.fill", size: 13, active: true) { mac.stopWaiting() }
                } else {
                    IconButton(symbol: "arrow.up", size: 14, weight: .bold, active: !mac.text.isEmpty) {
                        focused = false
                        mac.send()
                    }
                    .disabled(!link.isConnected)
                }
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            if !mac.request.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mac.request).font(Theme.font(12, .semibold)).foregroundStyle(Theme.tertiary)
                    ForEach(Array(mac.steps.suffix(3).enumerated()), id: \.offset) { item in
                        HStack(spacing: 6) {
                            Circle().fill(Theme.tertiary).frame(width: 4, height: 4)
                            Text(item.element).font(Theme.font(12)).foregroundStyle(Theme.secondary)
                        }
                    }
                    if let error = mac.error {
                        Text(error).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                    } else if mac.reply.isEmpty, mac.isBusy {
                        HStack(spacing: 8) { BlobCharacter(mood: .busy, size: 14); Text("Working on your Mac…").foregroundStyle(Theme.secondary) }
                            .font(Theme.font(13))
                    } else if !mac.reply.isEmpty {
                        Text((try? AttributedString(markdown: mac.reply,
                                                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                             ?? AttributedString(mac.reply))
                            .font(Theme.font(15)).foregroundStyle(Theme.ink).textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text("Tip: tap the mic on the keyboard to say it instead.")
                .font(Theme.font(11)).foregroundStyle(Theme.tertiary)
        }
        .animation(Springs.soft, value: mac.request)
    }

    private var statusRows: some View {
        VStack(spacing: 8) {
            StatusRow(symbol: "laptopcomputer", title: macTitle, value: link.isConnected ? "Connected" : "Not connected")
            if let active = link.sessions.first(where: { $0.state == "waiting" || $0.state == "working" }) {
                StatusRow(symbol: "sparkle", title: active.project,
                          value: active.state == "waiting" ? "Needs you" : "Working")
            }
            if let next = timers.timers.min(by: { $0.end < $1.end }) {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    StatusRow(symbol: "timer", title: next.label,
                              value: max(0, next.end.timeIntervalSince(ctx.date)).clock)
                }
            }
        }
    }

    private var macTitle: String {
        if case .connected(let name) = link.status { return name }
        if case .needsCode(let name) = link.status { return name }
        return "Your Mac"
    }

    private var quickTimers: some View {
        HStack(spacing: 8) {
            ForEach([1.0, 5, 10, 25], id: \.self) { m in
                Button { timers.add(minutes: m) } label: {
                    Label("\(Int(m))m", systemImage: "timer")
                        .font(Theme.font(13, .semibold)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: timers.timers.count)
            }
        }
    }
}

private struct StatusRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.secondary)
                .frame(width: 22)
            Text(title).font(Theme.font(14, .medium)).foregroundStyle(Theme.ink).lineLimit(1)
            Spacer()
            Text(value).font(Theme.digits(13)).foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
