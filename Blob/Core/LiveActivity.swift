import CoreGraphics

/// What the closed notch is showing in its wings, in priority order.
enum LiveActivity: Equatable {
    case none
    case notice(Notice)
    case timerDone
    case claude(ClaudeState)
    case timer
    case event
    case music

    var wingWidth: CGFloat {
        switch self {
        case .none: 0
        case .notice(let n): n.kind.wingWidth
        case .timerDone: 76
        case .claude: 86
        case .timer: 60
        case .event: 72
        case .music: 40
        }
    }

    /// Identity for transitions: a change of category cross-fades, a change of value doesn't.
    var category: String {
        switch self {
        case .none: "none"
        case .notice(let n): n.kind.category
        case .timerDone: "timerDone"
        case .claude(let s): "claude.\(s.rawValue)"
        case .timer: "timer"
        case .event: "event"
        case .music: "music"
        }
    }
}
