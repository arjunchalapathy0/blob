import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var clipboard: ClipboardService
    @State private var query = ""
    @FocusState private var searching: Bool

    private var visible: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return clipboard.items }
        return clipboard.items.filter { $0.text.localizedStandardContains(q) }
    }

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
                searchBar
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        if visible.isEmpty {
                            Text("No matches")
                                .font(Theme.font(12)).foregroundStyle(Theme.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(visible) { item in
                                ClipRow(item: item)
                            }
                        }
                    }
                    .animation(Springs.snap, value: clipboard.items)
                    .animation(Springs.snap, value: query)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiary)
            TextField("Search copies", text: $query)
                .textFieldStyle(.plain)
                .font(Theme.font(13))
                .foregroundStyle(Theme.ink)
                .focused($searching)
            if !query.isEmpty {
                IconButton(symbol: "xmark", size: 10, help: "Clear search") { query = "" }
            }
        }
        .padding(.leading, 12).padding(.trailing, query.isEmpty ? 12 : 4).padding(.vertical, 2)
        .background(Theme.fill, in: Capsule())
        .overlay(Capsule().strokeBorder(searching ? Theme.hairline : .clear))
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
