import SwiftUI
import UIKit

/// Ask about an image. Uses your Claude subscription through Blob on your Mac when connected,
/// otherwise an Anthropic API key if you've added one.
@MainActor
final class AskModel: ObservableObject {
    @Published var question = ""
    @Published var image: UIImage?
    @Published private(set) var askedQuestion = ""
    @Published private(set) var answer = ""
    @Published private(set) var error: String?
    @Published private(set) var isBusy = false
    @Published private(set) var hasKey = Keychain.read() != nil

    weak var link: MacLink?
    private var task: Task<Void, Never>?
    private var macAskID: String?

    var viaMac: Bool { link?.isConnected ?? false }
    var isReady: Bool { viaMac || hasKey }

    func setKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { Keychain.delete() } else { Keychain.save(trimmed) }
        hasKey = Keychain.read() != nil
    }

    func pasteImage() {
        if let pasted = UIPasteboard.general.image { image = pasted }
    }

    func cancel() {
        task?.cancel()
        if let id = macAskID { link?.cancelAsk(id) }
        macAskID = nil
        isBusy = false
    }

    func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isBusy, let image,
              let jpeg = Self.downscaled(image).jpegData(compressionQuality: 0.8) else { return }
        question = ""
        askedQuestion = q
        answer = ""
        error = nil

        if viaMac, let link {
            isBusy = true
            macAskID = link.ask(question: q, jpeg: jpeg) { [weak self] event, text in
                guard let self else { return }
                switch event {
                case .reset: self.answer = ""
                case .text: self.answer += text
                case .final: self.answer = text; self.finish()
                case .error: if self.answer.isEmpty { self.error = text }; self.finish()
                }
            }
            if macAskID == nil { error = "Couldn’t reach your Mac."; isBusy = false }
            return
        }

        guard let key = Keychain.read() else {
            error = "Connect to Blob on your Mac (Claude tab) or add an API key."
            return
        }
        isBusy = true
        task = Task {
            do {
                try await ClaudeClient.ask(question: q, jpeg: jpeg, key: key) { [weak self] text in
                    self?.answer += text
                }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
            isBusy = false
        }
    }

    private func finish() {
        macAskID = nil
        isBusy = false
    }

    /// Long edge about 1568 px keeps text legible while staying fast.
    private static func downscaled(_ image: UIImage) -> UIImage {
        let longEdge = max(image.size.width, image.size.height) * image.scale
        guard longEdge > 1568 else { return image }
        let factor = 1568 / longEdge
        let size = CGSize(width: image.size.width * image.scale * factor, height: image.size.height * image.scale * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
