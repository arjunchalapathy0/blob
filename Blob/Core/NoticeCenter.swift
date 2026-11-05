import SwiftUI

/// Short-lived things the notch shows in its wings: volume, brightness, "Copied", etc.
struct Notice: Equatable, Identifiable {
    enum Kind: Equatable {
        case volume(Float, muted: Bool)
        case brightness(Float)
        case message(symbol: String, text: String)

        var category: String {
            switch self {
            case .volume: "volume"
            case .brightness: "brightness"
            case .message(_, let text): "message:\(text)"
            }
        }

        var wingWidth: CGFloat {
            switch self {
            case .volume, .brightness: 70
            case .message: 104
            }
        }
    }

    var id = UUID()
    var kind: Kind
}

@MainActor
final class NoticeCenter: ObservableObject {
    @Published private(set) var current: Notice?
    private var hideTask: Task<Void, Never>?

    func post(_ kind: Notice.Kind, duration: TimeInterval = 1.6) {
        // Keep the same identity while the same kind updates, so levels animate in place.
        if let current, current.kind.category == kind.category {
            self.current = Notice(id: current.id, kind: kind)
        } else {
            current = Notice(kind: kind)
        }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func message(_ symbol: String, _ text: String, duration: TimeInterval = 2) {
        post(.message(symbol: symbol, text: text), duration: duration)
    }
}
