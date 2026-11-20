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
            var dirty = false
            items = saved.compactMap { item in
                var item = item
                guard let url = resolve(&item, dirty: &dirty),
                      FileManager.default.fileExists(atPath: url.path) else { return nil }
                return item
            }
            if dirty { save() }
        }
    }

    var urls: [URL] { items.compactMap(\.url) }

    /// Resolves a bookmark and rewrites it when the system marks it stale (file moved).
    @discardableResult
    private func resolve(_ item: inout ShelfItem, dirty: inout Bool) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI],
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            item.bookmark = fresh
            dirty = true
        }
        return url
    }

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
        if let url = resolvedURL(for: item) { NSWorkspace.shared.open(url) }
    }

    func reveal(_ items: [ShelfItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.compactMap { resolvedURL(for: $0) })
    }

    func airDrop(_ items: [ShelfItem]) {
        let urls = items.compactMap { resolvedURL(for: $0) }
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls) else { return }
        service.perform(withItems: urls)
    }

    func copy(_ items: [ShelfItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(items.compactMap { resolvedURL(for: $0) } as [NSURL])
    }

    func resolvedURL(for item: ShelfItem) -> URL? {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return item.url }
        var copy = items[i]
        var dirty = false
        let url = resolve(&copy, dirty: &dirty)
        if dirty {
            items[i] = copy
            save()
        }
        return url
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: file, options: .atomic) }
    }
}
