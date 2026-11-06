import ActivityKit
import Foundation

/// One Live Activity type for everything Blob shows in the Dynamic Island.
struct BlobActivityAttributes: ActivityAttributes {
    enum Kind: String, Codable, Hashable { case timer, event, claude }

    struct ContentState: Codable, Hashable {
        var mood: String          // Mood raw value
        var title: String
        var detail: String
        var endDate: Date?        // countdown target (timer end, event start)
        var startDate: Date?      // when the countdown began, for the progress bar
    }

    var kind: Kind
}
