import SwiftUI

/// The Ask tab when Claude Code is available: type or hold Right Option to tell Blob what to do.
struct AgentView: View {
    @EnvironmentObject private var agent: AgentService
    @State private var text = ""
    @FocusState private var focused: Bool

    private static let suggestions = ["Put on some music", "What’s on my screen?", "Open my Downloads", "Switch to dark mode"]

    var body: some View {
        VStack(spacing: 10) {
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            inputBar
        }
        .onAppear { focused = true }
    }

    @ViewBuilder private var content: some View {
        switch agent.phase {
        case .idle where agent.request.isEmpty:
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    BlobCharacter(mood: .curious, size: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tell Blob what to do on your Mac.").font(Theme.font(12, .semibold)).foregroundStyle(Theme.ink)
                        Text("Type below, or hold right ⌥ and talk.").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                    }
                }
                // A few things to try, one click each.
                HStack(spacing: 6) {
                    ForEach(Self.suggestions, id: \.self) { suggestion in
                        PillButton(title: suggestion) { agent.run(suggestion) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .listening:
            HStack(spacing: 12) {
                BlobCharacter(mood: .curious, size: 22)
                VoiceLevel(level: agent.level, bars: 12).frame(height: 22)
                Text("Listening…").font(Theme.font(12)).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .transcribing:
            HStack(spacing: 10) {
                BlobCharacter(mood: .busy, size: 20)
                Text(agent.whisperStatus == "Ready" ? "Transcribing…" : agent.whisperStatus)
                    .font(Theme.font(12)).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            transcript
        }
    }

    private var transcript: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text(agent.request).font(Theme.font(11, .semibold)).foregroundStyle(Theme.tertiary).lineLimit(2)
                if !agent.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(agent.steps.suffix(4).enumerated()), id: \.offset) { item in
                            HStack(spacing: 6) {
                                Circle().fill(Theme.tertiary).frame(width: 3, height: 3)
                                Text(item.element).font(Theme.font(11)).foregroundStyle(Theme.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                if let error = agent.error, agent.phase == .failed {
                    Text(error).font(Theme.font(12)).foregroundStyle(Theme.secondary)
                } else if agent.reply.isEmpty, agent.phase == .working {
                    HStack(spacing: 8) {
                        BlobCharacter(mood: .busy, size: 14)
                        Text(agent.currentStep + "…").font(Theme.font(12)).foregroundStyle(Theme.secondary)
                    }
                } else {
                    Text((try? AttributedString(markdown: agent.reply,
                                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                         ?? AttributedString(agent.reply))
                        .font(Theme.font(12.5)).foregroundStyle(Theme.ink).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiary)
            TextField("Tell Blob what to do…  or hold right ⌥", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.font(13))
                .foregroundStyle(Theme.ink)
                .focused($focused)
                .onSubmit(send)
            if agent.phase == .working {
                IconButton(symbol: "stop.fill", size: 10, active: true, help: "Stop") { agent.cancel() }
            } else if text.isEmpty, !agent.request.isEmpty {
                IconButton(symbol: "plus", size: 10, help: "New conversation") { agent.newConversation() }
            } else {
                IconButton(symbol: "arrow.up", size: 11, weight: .bold, active: !text.isEmpty, help: "Send", action: send)
            }
        }
        .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 2)
        .background(Theme.fill, in: Capsule())
        .overlay(Capsule().strokeBorder(focused ? Theme.hairline : .clear))
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        text = ""
        agent.run(t)
    }
}

/// Bars that follow the microphone level.
struct VoiceLevel: View {
    var level: Float
    var bars = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    let wobble = 0.55 + 0.45 * abs(sin(t * 7 + Double(i) * 1.3))
                    Capsule().fill(Theme.ink)
                        .frame(width: 2.5, height: max(3, 16 * CGFloat(level) * CGFloat(wobble)))
                }
            }
            .frame(maxHeight: .infinity)
            .animation(Springs.snap, value: level)
        }
    }
}
