import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @EnvironmentObject private var shelf: ShelfStore

    var body: some View {
        if shelf.items.isEmpty {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .overlay {
                    EmptyState(text: "Drop files here", detail: "Drag anything onto the notch to keep it close.", mood: .curious)
                }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "\(shelf.items.count) item\(shelf.items.count == 1 ? "" : "s")")
                    Spacer()
                    PillButton(title: "AirDrop", symbol: "airplayaudio") { shelf.airDrop(shelf.items) }
                    PillButton(title: "Clear", symbol: "xmark") { withAnimation(Springs.snap) { shelf.clear() } }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shelf.items) { item in
                            ShelfTile(item: item)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .animation(Springs.wobble, value: shelf.items)
                }
            }
        }
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    @EnvironmentObject private var shelf: ShelfStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let url = item.url {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                } else {
                    Image(systemName: "questionmark.square.dashed").resizable().foregroundStyle(Theme.tertiary)
                }
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 46, height: 46)
            Text(item.name)
                .font(Theme.font(10)).foregroundStyle(Theme.secondary)
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 76)
        }
        .padding(8)
        .background(hovering ? Theme.fillStrong : Theme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { withAnimation(Springs.snap) { shelf.remove(item) } } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black).frame(width: 16, height: 16)
                        .background(Theme.ink, in: Circle())
                }
                .buttonStyle(PressStyle())
                .offset(x: 4, y: -4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(Springs.snap, value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { shelf.open(item) }
        .onDrag { item.url.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { shelf.open(item) }
            Button("Show in Finder") { shelf.reveal([item]) }
            Button("Copy") { shelf.copy([item]) }
            Button("AirDrop") { shelf.airDrop([item]) }
            Divider()
            Button("Remove") { shelf.remove(item) }
        }
    }
}
