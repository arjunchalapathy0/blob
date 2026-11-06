import SwiftUI

/// Tell your Mac what to do from the phone. Blob on the Mac carries it out with Claude Code.
@MainActor
final class MacTaskModel: ObservableObject {
    @Published var text = ""
    @Published private(set) var request = ""
    @Published private(set) var reply = ""
    @Published private(set) var steps: [String] = []
    @Published private(set) var error: String?
    @Published private(set) var isBusy = false
    @Published private(set) var finishedCount = 0

    weak var link: MacLink?
    private var taskID: String?

    func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !isBusy, let link else { return }
        text = ""
        request = t
        reply = ""
        steps = []
        error = nil
        isBusy = true
        taskID = link.task(t) { [weak self] event, value in
            guard let self else { return }
            switch event {
            case .reset: self.reply = ""
            case .text: self.reply += value
            case .step: if self.steps.last != value { self.steps.append(value) }
            case .final: self.reply = value; self.finish()
            case .error: if self.reply.isEmpty { self.error = value }; self.finish()
            }
        }
        if taskID == nil {
            error = "Not connected to your Mac."
            isBusy = false
        }
    }

    func stopWaiting() {
        if let id = taskID { link?.cancelAsk(id) }
        taskID = nil
        isBusy = false
    }

    private func finish() {
        taskID = nil
        isBusy = false
        finishedCount += 1
    }
}
