import SwiftUI

struct AskView: View {
    let screen: NSScreen
    @EnvironmentObject private var ask: AskService
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if !ask.isReady {
                EmptyState(text: "Ask about your screen",
                           detail: "Install Claude Code and sign in to use your Claude subscription, or add an API key in Settings.",
                           mood: .curious, actionTitle: "Open Settings") { SettingsWindow.show() }
            } else if !ask.canCapture {
                EmptyState(text: "Let Blob see your screen",
                           detail: "Allow Screen Recording. Blob only captures when you ask a question.",
                           mood: .curious, actionTitle: "Allow") { ask.requestScreenAccess() }
            } else {
                VStack(spacing: 10) {
                    if ask.hasResult { result } else { hint }
                    inputBar
                }
            }
        }
        .onAppear {
            ask.refreshPermissions()
            focused = true
        }
    }

    private var hint: some View {
        HStack(spacing: 12) {
            BlobCharacter(mood: .curious, size: 22)
            Text("Ask anything about what’s on your screen.")
                .font(Theme.font(12)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var result: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if let snapshot = ask.snapshot {
                    Image(nsImage: snapshot).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Theme.fill
                }
            }
            .frame(width: 84, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ask.askedQuestion)
                        .font(Theme.font(11, .semibold)).foregroundStyle(Theme.tertiary).lineLimit(2)
                    if let error = ask.error {
                        Text(error).font(Theme.font(12)).foregroundStyle(Theme.secondary)
                    } else if ask.answer.isEmpty {
                        HStack(spacing: 8) {
                            BlobCharacter(mood: .busy, size: 14)
                            Text("Looking…").font(Theme.font(12)).foregroundStyle(Theme.secondary)
                        }
                    } else {
                        Text(Self.markdown(ask.answer))
                            .font(Theme.font(12.5)).foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiary)
            TextField("Ask about your screen…", text: $ask.question)
                .textFieldStyle(.plain)
                .font(Theme.font(13))
                .foregroundStyle(Theme.ink)
                .focused($focused)
                .onSubmit { ask.ask(on: screen) }
            if ask.isBusy {
                IconButton(symbol: "stop.fill", size: 10, active: true, help: "Stop") { ask.cancel() }
            } else if ask.hasResult && ask.question.isEmpty {
                IconButton(symbol: "xmark", size: 10, help: "Clear") { ask.clear() }
            } else {
                IconButton(symbol: "arrow.up", size: 11, weight: .bold, active: !ask.question.isEmpty, help: "Ask") {
                    ask.ask(on: screen)
                }
            }
        }
        .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 2)
        .background(Theme.fill, in: Capsule())
        .overlay(Capsule().strokeBorder(focused ? Theme.hairline : .clear))
    }

    private static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
