import SwiftUI
import UIKit

@MainActor
final class AskModel: ObservableObject {
    @Published var question = ""
    @Published var image: UIImage?
    @Published private(set) var askedQuestion = ""
    @Published private(set) var answer = ""
    @Published private(set) var error: String?
    @Published private(set) var isBusy = false
    @Published private(set) var hasKey = Keychain.read() != nil
    private var task: Task<Void, Never>?

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
        isBusy = false
    }

    func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isBusy, let image, let key = Keychain.read(),
              let jpeg = Self.downscaled(image).jpegData(compressionQuality: 0.8) else { return }
        question = ""
        askedQuestion = q
        answer = ""
        error = nil
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
