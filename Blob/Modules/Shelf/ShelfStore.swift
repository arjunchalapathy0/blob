import AppKit
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var bookmark: Data
    var name: String
    var added = Date()

    var url: URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}

/// Files parked in the notch. Survives restarts and follows files that move.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let file: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Blob", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shelf.json")
    }()

    init() {
        if let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            items = saved.filter { $0.url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }
        }
    }

    var urls: [URL] { items.compactMap(\.url) }

    func add(providers: [NSItemProvider]) {
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url, url.isFileURL else { return }
                Task { @MainActor in self?.add(urls: [url]) }
            }
        }
    }

    func add(urls: [URL]) {
        for url in urls {
            guard !items.contains(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }),
                  let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            else { continue }
            items.append(ShelfItem(bookmark: bookmark, name: url.lastPathComponent))
        }
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func open(_ item: ShelfItem) {
        if let url = item.url { NSWorkspace.shared.open(url) }
    }

    func reveal(_ items: [ShelfItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.compactMap(\.url))
    }

    func airDrop(_ items: [ShelfItem]) {
        let urls = items.compactMap(\.url)
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls) else { return }
        service.perform(withItems: urls)
    }

    func copy(_ items: [ShelfItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(items.compactMap(\.url) as [NSURL])
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: file, options: .atomic) }
    }
}
