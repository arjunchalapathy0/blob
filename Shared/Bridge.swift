import Foundation

/// The protocol between Blob on the Mac and Blob on iPhone over the local network
/// (Bonjour + TCP, one JSON object per line).
///
/// iPhone → Mac:  hello {code}, ask {id, question, image (base64 JPEG)}, task {id, text}
/// Mac → iPhone:  snapshot {host, sessions}, denied, askEvent {id, event, text}
///
/// Nothing is sent until the phone says hello with the pairing code shown in the Mac's Settings.
enum Bridge {
    static let serviceType = "_blob._tcp"

    struct Session: Codable, Identifiable, Hashable {
        var id: String
        var project: String
        var state: String   // idle | working | waiting | done
        var detail: String
        var updated: Date
    }

    enum AskEvent: String { case reset, text, final, error, step }

    enum Message {
        case hello(code: String)
        case ask(id: String, question: String, image: String)
        case task(id: String, text: String)
        case snapshot(host: String, sessions: [Session])
        case denied
        case askEvent(id: String, event: AskEvent, text: String)
    }

    static func encode(_ message: Message) -> Data {
        var obj: [String: Any]
        switch message {
        case .hello(let code):
            obj = ["type": "hello", "code": code]
        case .ask(let id, let question, let image):
            obj = ["type": "ask", "id": id, "question": question, "image": image]
        case .task(let id, let text):
            obj = ["type": "task", "id": id, "text": text]
        case .snapshot(let host, let sessions):
            obj = ["type": "snapshot", "host": host, "sessions": sessions.map {
                ["id": $0.id, "project": $0.project, "state": $0.state, "detail": $0.detail,
                 "updated": $0.updated.timeIntervalSince1970] as [String: Any]
            }]
        case .denied:
            obj = ["type": "denied"]
        case .askEvent(let id, let event, let text):
            obj = ["type": "askEvent", "id": id, "event": event.rawValue, "text": text]
        }
        var data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
        data.append(0x0A)
        return data
    }

    static func decode(_ line: Data) -> Message? {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return nil }
        switch obj["type"] as? String {
        case "hello":
            return .hello(code: obj["code"] as? String ?? "")
        case "ask":
            guard let id = obj["id"] as? String, let q = obj["question"] as? String, let img = obj["image"] as? String
            else { return nil }
            return .ask(id: id, question: q, image: img)
        case "task":
            guard let id = obj["id"] as? String, let text = obj["text"] as? String else { return nil }
            return .task(id: id, text: text)
        case "snapshot":
            let sessions = (obj["sessions"] as? [[String: Any]] ?? []).compactMap { s -> Session? in
                guard let id = s["id"] as? String else { return nil }
                return Session(id: id, project: s["project"] as? String ?? "", state: s["state"] as? String ?? "idle",
                               detail: s["detail"] as? String ?? "",
                               updated: Date(timeIntervalSince1970: (s["updated"] as? NSNumber)?.doubleValue ?? 0))
            }
            return .snapshot(host: obj["host"] as? String ?? "Mac", sessions: sessions)
        case "denied":
            return .denied
        case "askEvent":
            guard let id = obj["id"] as? String, let event = AskEvent(rawValue: obj["event"] as? String ?? "")
            else { return nil }
            return .askEvent(id: id, event: event, text: obj["text"] as? String ?? "")
        default:
            return nil
        }
    }

    /// Splits complete lines off a receive buffer.
    static func takeLines(from buffer: inout Data) -> [Data] {
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            lines.append(buffer.subdata(in: buffer.startIndex..<newline))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }
}
