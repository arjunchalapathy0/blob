import ActivityKit
import Foundation

/// Starts, updates and ends Blob's Live Activities.
@MainActor
enum IslandManager {
    static var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    @discardableResult
    static func start(kind: BlobActivityAttributes.Kind, state: BlobActivityAttributes.ContentState,
                      staleDate: Date? = nil) -> String? {
        guard isEnabled else { return nil }
        let content = ActivityContent(state: state, staleDate: staleDate)
        return try? Activity.request(attributes: BlobActivityAttributes(kind: kind), content: content, pushType: nil).id
    }

    static func update(id: String, state: BlobActivityAttributes.ContentState, staleDate: Date? = nil) {
        guard let activity = activity(id) else { return }
        Task { await activity.update(ActivityContent(state: state, staleDate: staleDate)) }
    }

    static func end(id: String?, after seconds: TimeInterval? = nil) {
        guard let id, let activity = activity(id) else { return }
        let policy: ActivityUIDismissalPolicy = seconds.map { .after(Date().addingTimeInterval($0)) } ?? .immediate
        Task { await activity.end(nil, dismissalPolicy: policy) }
    }

    static func activities(of kind: BlobActivityAttributes.Kind) -> [Activity<BlobActivityAttributes>] {
        Activity<BlobActivityAttributes>.activities.filter { $0.attributes.kind == kind }
    }

    private static func activity(_ id: String) -> Activity<BlobActivityAttributes>? {
        Activity<BlobActivityAttributes>.activities.first { $0.id == id }
    }
}
