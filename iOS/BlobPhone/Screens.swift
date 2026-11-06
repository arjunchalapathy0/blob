import EventKit
import PhotosUI
import SwiftUI

/// Big title with the character beside it.
struct ScreenHeader: View {
    let title: String
    var mood: Mood = .idle

    var body: some View {
        HStack(spacing: 12) {
            BlobCharacter(mood: mood, size: 26)
            Text(title).font(Theme.font(28, .bold)).foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Timers

struct TimersScreen: View {
    @EnvironmentObject private var timers: TimerStore
    private let presets: [Double] = [1, 3, 5, 10, 15, 25, 45, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Timers", mood: timers.timers.isEmpty ? .idle : .busy)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(presets, id: \.self) { m in
                        Button { withAnimation(Springs.wobble) { timers.add(minutes: m) } } label: {
                            Text(m < 60 ? "\(Int(m))m" : "1h")
                                .font(Theme.font(15, .semibold)).foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                if !IslandManager.isEnabled {
                    Text("Turn on Live Activities for Blob in Settings to see timers in the Dynamic Island.")
                        .font(Theme.font(12)).foregroundStyle(Theme.tertiary)
                }
                ForEach(timers.timers) { timer in
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let remaining = max(0, timer.end.timeIntervalSince(ctx.date))
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(remaining > 0 ? remaining.clock : "Done")
                                    .font(Theme.digits(30, .semibold)).foregroundStyle(Theme.ink)
                                Text(timer.label).font(Theme.font(12)).foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            IconButton(symbol: "xmark", size: 13) { withAnimation(Springs.snap) { timers.cancel(timer) } }
                        }
                        .padding(16)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .padding(20)
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in timers.sweep() }
    }
}

// MARK: - Ask

struct AskScreen: View {
    @EnvironmentObject private var ask: AskModel
    @EnvironmentObject private var link: MacLink
    @State private var pick: PhotosPickerItem?
    @State private var key = ""
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Ask", mood: ask.isBusy ? .busy : .curious)
                if !ask.isReady { keyCard } else { content }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: pick) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    ask.image = image
                }
            }
        }
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect to Blob on your Mac (Claude tab) to ask using your Claude subscription. Or add an Anthropic API key; it stays in your Keychain.")
                .font(Theme.font(13)).foregroundStyle(Theme.secondary)
            SecureField("sk-ant-…", text: $key)
                .font(Theme.font(15)).padding(12)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            PillButton(title: "Save key", prominent: true) { ask.setKey(key); key = "" }
        }
    }

    @ViewBuilder private var content: some View {
        Text(ask.viaMac ? "Answers through your Mac · Claude subscription" : "Answers with your API key")
            .font(Theme.font(11)).foregroundStyle(Theme.tertiary)

        HStack(spacing: 8) {
            PhotosPicker(selection: $pick, matching: .images) {
                Label("Choose", systemImage: "photo").font(Theme.font(13, .semibold))
                    .foregroundStyle(Theme.ink).padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Theme.fillStrong, in: Capsule())
            }
            PillButton(title: "Paste", symbol: "doc.on.clipboard") { ask.pasteImage() }
            Spacer()
        }

        if let image = ask.image {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
                .frame(maxWidth: .infinity)
        }

        HStack(spacing: 8) {
            TextField("Ask about this image…", text: $ask.question, axis: .vertical)
                .font(Theme.font(15)).foregroundStyle(Theme.ink)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { ask.ask() }
            if ask.isBusy {
                IconButton(symbol: "stop.fill", size: 13, active: true) { ask.cancel() }
            } else {
                IconButton(symbol: "arrow.up", size: 14, weight: .bold, active: !ask.question.isEmpty && ask.image != nil) {
                    focused = false
                    ask.ask()
                }
                .disabled(ask.image == nil)
            }
        }
        .padding(.leading, 14).padding(.trailing, 4).padding(.vertical, 4)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

        if ask.image == nil {
            Text("Choose or paste a screenshot first.").font(Theme.font(12)).foregroundStyle(Theme.tertiary)
        }

        if !ask.askedQuestion.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(ask.askedQuestion).font(Theme.font(12, .semibold)).foregroundStyle(Theme.tertiary)
                if let error = ask.error {
                    Text(error).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                } else if ask.answer.isEmpty {
                    HStack { BlobCharacter(mood: .busy, size: 16); Text("Looking…").foregroundStyle(Theme.secondary) }
                } else {
                    Text((try? AttributedString(markdown: ask.answer,
                                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                         ?? AttributedString(ask.answer))
                        .font(Theme.font(15)).foregroundStyle(Theme.ink).textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }

        if ask.hasKey {
            Button("Remove API key") { ask.setKey("") }
                .font(Theme.font(11)).foregroundStyle(Theme.tertiary).padding(.top, 12)
        }
    }
}

// MARK: - Claude

struct ClaudeScreen: View {
    @EnvironmentObject private var link: MacLink
    @State private var code = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Claude", mood: mood)
                HStack(spacing: 8) {
                    Circle().fill(connected ? Theme.ink : Theme.tertiary).frame(width: 7, height: 7)
                    Text(statusText).font(Theme.font(13)).foregroundStyle(Theme.secondary)
                }
                if case .needsCode(let mac) = link.status {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enter the pairing code from Blob on \(mac): Settings → Claude Code.")
                            .font(Theme.font(13)).foregroundStyle(Theme.secondary)
                        HStack {
                            TextField("000000", text: $code)
                                .keyboardType(.numberPad)
                                .font(Theme.digits(22, .semibold))
                                .padding(12)
                                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            PillButton(title: "Pair", prominent: true) { link.pair(code: code); code = "" }
                                .disabled(code.filter(\.isNumber).count != 6)
                        }
                    }
                }
                Toggle("Show on Lock Screen", isOn: Binding(get: { link.showsInIsland }, set: { link.showsInIsland = $0 }))
                    .font(Theme.font(14, .medium)).tint(Theme.ink.opacity(0.8))
                if !connected {
                    Text("On your Mac, open Blob → Settings → Claude Code and turn on “Show on iPhone”. Both devices need to be on the same Wi-Fi.")
                        .font(Theme.font(12)).foregroundStyle(Theme.tertiary)
                }
                ForEach(link.sessions) { s in
                    HStack(spacing: 12) {
                        BlobCharacter(mood: Self.mood(for: s.state), size: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.project).font(Theme.font(15, .semibold)).foregroundStyle(Theme.ink)
                            Text(s.detail).font(Theme.font(12)).foregroundStyle(Theme.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(s.updated, style: .relative).font(Theme.font(11)).foregroundStyle(Theme.tertiary)
                    }
                    .padding(14)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Text("Updates arrive while Blob is open on your iPhone. iOS pauses it in the background.")
                    .font(Theme.font(11)).foregroundStyle(Theme.tertiary).padding(.top, 6)
            }
            .padding(20)
        }
    }

    private var connected: Bool { if case .connected = link.status { return true }; return false }

    private var statusText: String {
        switch link.status {
        case .searching: "Looking for your Mac…"
        case .needsCode(let name): "Found \(name) · needs pairing"
        case .connected(let name): "Connected to \(name)"
        }
    }

    private var mood: Mood {
        if link.sessions.contains(where: { $0.state == "waiting" }) { return .alarmed }
        if link.sessions.contains(where: { $0.state == "working" }) { return .busy }
        return connected ? .idle : .sleepy
    }

    static func mood(for state: String) -> Mood {
        switch state {
        case "working": .busy
        case "waiting": .alarmed
        case "done": .happy
        default: .sleepy
        }
    }
}

// MARK: - Calendar

struct CalendarScreen: View {
    @EnvironmentObject private var calendar: CalendarStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Today", mood: .idle)
                if !calendar.authorized {
                    EmptyState(text: "See what’s next", detail: "Allow calendar access to count down to events in the Dynamic Island.",
                               mood: .curious, actionTitle: "Allow") { Task { await calendar.requestAccess() } }
                        .frame(height: 160)
                } else if calendar.events.isEmpty {
                    EmptyState(text: "Nothing else today", detail: "Enjoy the quiet.", mood: .sleepy).frame(height: 140)
                } else {
                    ForEach(calendar.events, id: \.calendarItemIdentifier) { event in
                        let inIsland = calendar.islandEventID == event.calendarItemIdentifier
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title ?? "Untitled").font(Theme.font(15, .semibold)).foregroundStyle(Theme.ink)
                                Text((event.startDate as Date).formatted(date: .omitted, time: .shortened))
                                    .font(Theme.font(12)).foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            PillButton(title: inIsland ? "Showing" : "Island", symbol: inIsland ? "checkmark" : "capsule",
                                       prominent: inIsland) {
                                inIsland ? calendar.hideFromIsland() : calendar.showInIsland(event)
                            }
                        }
                        .padding(14)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .onAppear { calendar.refresh() }
    }
}
