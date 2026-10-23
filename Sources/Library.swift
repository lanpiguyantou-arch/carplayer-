import Foundation

struct MediaItem: Identifiable, Hashable, Codable {
    var id: String { url.absoluteString }
    let url: URL
    let title: String
    let isRemote: Bool
}

final class Library: ObservableObject {
    static let shared = Library()
    static let playableExts: Set<String> = ["mp4", "m4v", "mov", "3gp", "m3u8", "mp3", "m4a", "aac", "wav", "flac"]

    @Published private(set) var localItems: [MediaItem] = []
    @Published private(set) var remoteItems: [MediaItem] = []
    private let remoteKey = "remoteItems"

    var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var all: [MediaItem] { localItems + remoteItems }

    init() { reload() }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
        localItems = files
            .filter { Library.playableExts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MediaItem(url: $0, title: $0.deletingPathExtension().lastPathComponent, isRemote: false) }
        if let data = UserDefaults.standard.data(forKey: remoteKey),
           let items = try? JSONDecoder().decode([MediaItem].self, from: data) {
            remoteItems = items
        }
    }

    func importFile(_ src: URL) {
        let access = src.startAccessingSecurityScopedResource()
        defer { if access { src.stopAccessingSecurityScopedResource() } }
        let dest = documents.appendingPathComponent(src.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: src, to: dest)
        reload()
    }

    func addRemote(_ raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: s), url.scheme != nil else { return }
        let name = url.deletingPathExtension().lastPathComponent
        let title = name.isEmpty || name == "/" ? (url.host ?? s) : name
        remoteItems.append(MediaItem(url: url, title: title, isRemote: true))
        saveRemote()
    }

    func delete(_ item: MediaItem) {
        if item.isRemote {
            remoteItems.removeAll { $0 == item }
            saveRemote()
        } else {
            try? FileManager.default.removeItem(at: item.url)
            let srt = item.url.deletingPathExtension().appendingPathExtension("srt")
            try? FileManager.default.removeItem(at: srt)
            reload()
        }
    }

    private func saveRemote() {
        if let data = try? JSONEncoder().encode(remoteItems) {
            UserDefaults.standard.set(data, forKey: remoteKey)
        }
    }
}
