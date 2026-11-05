import SwiftUI

struct QuickToolsView: View {
    @EnvironmentObject private var tools: QuickToolsService
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Tool(symbol: tools.isCaffeinated ? "cup.and.saucer.fill" : "cup.and.saucer",
                 title: tools.isCaffeinated ? "Awake" : "Keep awake", active: tools.isCaffeinated) {
                tools.toggleCaffeinate()
            }
            Tool(symbol: "eyedropper", title: "Pick color") {
                close()
                after(0.35) { tools.pickColor() }
            }
            Tool(symbol: "camera.viewfinder", title: "Screenshot") {
                close()
                after(0.35) { tools.screenshot() }
            }
            Tool(symbol: "circle.lefthalf.filled", title: "Appearance") { tools.toggleDarkMode() }
            Tool(symbol: "display", title: "Sleep display") {
                close()
                after(0.4) { tools.sleepDisplay() }
            }
            Tool(symbol: "waveform.path.ecg", title: "Activity") {
                close()
                tools.openActivityMonitor()
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            work()
        }
    }
}

private struct Tool: View {
    let symbol: String
    let title: String
    var active = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(active ? Color.black : Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(active ? Theme.ink : (hovering ? Theme.fillStrong : Theme.fill),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentTransition(.symbolEffect(.replace))
                Text(title).font(Theme.font(10, .medium)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(Springs.snap, value: hovering)
        .animation(Springs.wobble, value: active)
    }
}
