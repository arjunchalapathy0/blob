import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BlobIslandBundle: WidgetBundle {
    var body: some Widget { BlobIslandWidget() }
}

struct BlobIslandWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlobActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BlobFace(mood: context.displayMood, size: 26)
                        .padding(.leading, 6)
                        .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingValue(context: context, large: true)
                        .padding(.trailing, 6)
                        .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        if !context.state.detail.isEmpty {
                            Text(context.state.detail)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                BlobFace(mood: context.displayMood, size: 14)
            } compactTrailing: {
                TrailingValue(context: context, large: false)
            } minimal: {
                BlobFace(mood: context.displayMood, size: 13)
            }
            .keylineTint(.white)
        }
    }
}

/// The main view on phones without a Dynamic Island (like iPhone 11 Pro): big, calm, readable at a glance.
private struct LockScreenView: View {
    let context: ActivityViewContext<BlobActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                BlobFace(mood: context.displayMood, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(context.isUrgent ? 1 : 0.56))
                        .textCase(.uppercase)
                    Text(context.state.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if !context.state.detail.isEmpty {
                        Text(context.state.detail)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.56))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                TrailingValue(context: context, large: true)
            }
            if let start = context.state.startDate, let end = context.state.endDate, end > start,
               !context.isStale, end > .now {
                ProgressView(timerInterval: start...end, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
    }

    private var headline: String {
        switch context.attributes.kind {
        case .timer: return context.isStale ? "Time’s up" : "Timer"
        case .event: return context.isStale ? "Starting now" : "Up next"
        case .claude: return "Claude · \(context.wordLabel)"
        }
    }
}

/// Countdown while running; a word once it's over or for Claude status.
private struct TrailingValue: View {
    let context: ActivityViewContext<BlobActivityAttributes>
    let large: Bool

    var body: some View {
        Group {
            if let end = context.state.endDate, !context.isStale, end > .now {
                Text(timerInterval: Date.now...end, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: large ? 76 : 44)
            } else {
                Text(context.wordLabel)
            }
        }
        .font(.system(size: large ? 22 : 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

extension ActivityViewContext where Attributes == BlobActivityAttributes {
    var displayMood: Mood {
        if isStale {
            switch attributes.kind {
            case .timer: return .alarmed
            case .event: return .curious
            case .claude: break
            }
        }
        return Mood(rawValue: state.mood) ?? .idle
    }

    /// Needs attention: a finished timer, or Claude waiting for you.
    var isUrgent: Bool {
        (attributes.kind == .timer && isStale) || (attributes.kind == .claude && state.mood == Mood.alarmed.rawValue)
    }

    var wordLabel: String {
        switch attributes.kind {
        case .timer: return "Done"
        case .event: return "Now"
        case .claude:
            switch state.mood {
            case Mood.alarmed.rawValue: return "Needs you"
            case Mood.busy.rawValue: return "Working"
            default: return "Done"
            }
        }
    }
}
