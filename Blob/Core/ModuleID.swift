import Foundation

enum ModuleID: String, CaseIterable, Identifiable {
    case nowPlaying, ask, shelf, clipboard, calendar, timers, claude, tools, stats, camera

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .ask: "Ask"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .calendar: "Calendar"
        case .timers: "Timers"
        case .claude: "Claude Code"
        case .tools: "Tools"
        case .stats: "Stats"
        case .camera: "Mirror"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .ask: "waveform"
        case .shelf: "tray"
        case .clipboard: "list.clipboard"
        case .calendar: "calendar"
        case .timers: "timer"
        case .claude: "sparkle"
        case .tools: "square.grid.2x2"
        case .stats: "gauge.with.dots.needle.33percent"
        case .camera: "camera"
        }
    }

    var prefKey: String { "module.\(rawValue)" }
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: prefKey) }

    static var enabled: [ModuleID] { allCases.filter(\.isEnabled) }
}
