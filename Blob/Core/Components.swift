import SwiftUI

/// Rounded, quiet container used throughout the open notch.
struct Card<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Monochrome icon button with a soft press.
struct IconButton: View {
    let symbol: String
    var size: CGFloat = 14
    var weight: Font.Weight = .semibold
    var active = false
    var help: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(active ? Theme.ink : Theme.secondary)
                .frame(width: size * 2, height: size * 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .help(help ?? "")
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Springs.wobble, value: configuration.isPressed)
    }
}

/// Small pill button with a label.
struct PillButton: View {
    let title: String
    var symbol: String? = nil
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
                Text(title).font(Theme.font(11, .semibold))
            }
            .foregroundStyle(prominent ? Color.black : Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(prominent ? Theme.ink : Theme.fillStrong, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

/// Horizontal level indicator (volume, brightness, progress).
struct LevelBar: View {
    var value: Double
    var height: CGFloat = 5
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.fillStrong)
                Capsule().fill(Theme.ink)
                    .frame(width: max(height, geo.size.width * CGFloat(max(0, min(1, value)))))
                    .opacity(value <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(Springs.snap, value: value)
    }
}

/// Tiny line chart for stats.
struct Sparkline: View {
    var values: [Double]
    var maxValue: Double? = nil
    var body: some View {
        GeometryReader { geo in
            let top = maxValue ?? max(values.max() ?? 1, 0.0001)
            let n = max(values.count - 1, 1)
            Path { p in
                for (i, v) in values.enumerated() {
                    let pt = CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(n),
                                     y: geo.size.height * (1 - CGFloat(min(v / top, 1))))
                    i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
            }
            .stroke(Theme.ink.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Empty state with the character.
struct EmptyState: View {
    let text: String
    var detail: String? = nil
    var mood: Mood = .idle
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            BlobCharacter(mood: mood, size: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(text).font(Theme.font(13, .semibold)).foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail).font(Theme.font(11)).foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let actionTitle, let action {
                    PillButton(title: actionTitle, prominent: true, action: action).padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Small uppercase label.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(9, .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.tertiary)
    }
}

extension TimeInterval {
    /// 4:05, 1:02:03
    var clock: String {
        let s = Int(self.rounded(.down))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}
