import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var clipboard: ClipboardService

    var body: some View {
        if clipboard.items.isEmpty {
            EmptyState(text: "Clipboard is empty", detail: "Things you copy show up here. Passwords are skipped.", mood: .idle)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "History")
                    Spacer()
                    PillButton(title: "Clear", symbol: "xmark") { withAnimation(Springs.snap) { clipboard.clearUnpinned() } }
                }
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(clipboard.items) { item in
                            ClipRow(item: item)
                        }
                    }
                    .animation(Springs.snap, value: clipboard.items)
                }
            }
        }
    }
}

private struct ClipRow: View {
    let item: ClipItem
    @EnvironmentObject private var clipboard: ClipboardService
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind == .file ? "doc" : "text.alignleft")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.tertiary)
                .frame(width: 14)
            Text(item.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces))
                .font(Theme.font(12)).foregroundStyle(Theme.ink).lineLimit(1)
            Spacer(minLength: 8)
            if hovering || item.pinned {
                Button { clipboard.togglePin(item) } label: {
                    Image(systemName: item.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(item.pinned ? Theme.ink : Theme.tertiary)
                }
                .buttonStyle(PressStyle())
            }
            Text(item.date, style: .relative)
                .font(Theme.font(10)).foregroundStyle(Theme.tertiary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(hovering ? Theme.fillStrong : Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { clipboard.copy(item) }
        .contextMenu {
            Button("Copy") { clipboard.copy(item) }
            Button(item.pinned ? "Unpin" : "Pin") { clipboard.togglePin(item) }
            Button("Delete") { clipboard.remove(item) }
        }
        .animation(Springs.snap, value: hovering)
    }
}
