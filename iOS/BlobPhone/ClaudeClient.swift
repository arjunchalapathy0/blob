import Foundation

/// Streams an answer from Claude about an image and a question.
enum ClaudeClient {
    static let model = "claude-opus-5-5"

    enum Failure: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
    }

    static func ask(question: String, jpeg: Data, key: String, onText: @escaping @MainActor (String) -> Void) async throws {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "stream": true,
            "fallbacks": "default",
            "output_config": ["effort": "medium"],
            "system": """
            You are Blob, a small assistant on the user's iPhone. They are asking about an image they \
            shared, usually a screenshot. Answer directly and briefly: a few sentences or a short list. \
            Use Markdown sparingly.
            """,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": question],
                ],
            ]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var text = ""
            for try await line in bytes.lines { text += line }
            let message = ((try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
            throw Failure.message(status == 401 ? "Your API key was rejected." : message ?? "Request failed (\(status)).")
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:"),
                  let event = try? JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8)) as? [String: Any]
            else { continue }
            switch event["type"] as? String {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    await onText(text)
                }
            case "message_delta":
                if (event["delta"] as? [String: Any])?["stop_reason"] as? String == "refusal" {
                    throw Failure.message("Claude declined to answer this one.")
                }
            case "error":
                throw Failure.message(((event["error"] as? [String: Any])?["message"] as? String) ?? "Something went wrong.")
            default:
                break
            }
        }
    }
}
