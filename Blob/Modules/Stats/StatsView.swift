import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var stats: StatsService

    var body: some View {
        HStack(spacing: 10) {
            StatCard(title: "CPU", value: percent(stats.cpu.last ?? 0)) {
                Sparkline(values: stats.cpu, maxValue: 1)
            }
            StatCard(title: "Memory",
                     value: ByteCountFormatter.string(fromByteCount: Int64(stats.memory.used), countStyle: .memory),
                     detail: "of " + ByteCountFormatter.string(fromByteCount: Int64(stats.memory.total), countStyle: .memory)) {
                Sparkline(values: stats.memoryHistory, maxValue: 1)
            }
            StatCard(title: "Network", value: "↓ " + (stats.down.last ?? 0).byteRate,
                     detail: "↑ " + (stats.up.last ?? 0).byteRate) {
                Sparkline(values: stats.down)
            }
            if let battery = stats.battery {
                StatCard(title: "Battery", value: percent(battery.level),
                         detail: battery.isCharging ? "Charging" : battery.onAC ? "Plugged in" : "On battery") {
                    LevelBar(value: battery.level, height: 6).frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .onAppear { stats.setVisible(true) }
        .onDisappear { stats.setVisible(false) }
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
}

private struct StatCard<Chart: View>: View {
    let title: String
    let value: String
    var detail: String? = nil
    @ViewBuilder var chart: Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(text: title)
            Text(value).font(Theme.digits(17, .semibold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(detail ?? " ").font(Theme.font(10)).foregroundStyle(Theme.tertiary).lineLimit(1)
            chart.frame(maxHeight: .infinity).padding(.top, 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(Springs.soft, value: value)
    }
}
