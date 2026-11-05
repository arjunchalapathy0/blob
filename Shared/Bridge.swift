import Foundation

/// The tiny protocol Blob on the Mac uses to stream Claude Code status to Blob on iPhone
/// over the local network (Bonjour + TCP, one JSON object per line).
enum Bridge {
    static let serviceType = "_blob._tcp"

    struct Session: Codable, Identifiable, Hashable {
        var id: String
        var project: String
        var state: String   // idle | working | waiting | done
        var detail: String
        var updated: Date
    }

    struct Snapshot: Codable {
        var host: String
        var sessions: [Session]
    }

    static func encode(_ snapshot: Snapshot) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var data = (try? encoder.encode(snapshot)) ?? Data()
        data.append(0x0A)
        return data
    }

    static func decode(_ line: Data) -> Snapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(Snapshot.self, from: line)
    }
}
