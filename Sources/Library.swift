import Foundation

struct MediaItem: Identifiable, Hashable, Codable {
    var id: String { url.absoluteString + "|" + title }
    let url: URL
    let title: String
    let isRemote: Bool
    var group: String?
    var logo: String?
}

final class Library: ObservableObject {
    static let shared = Library()
    static let playableExts: Set<String> = ["mp4", "m4v", "mov", "3gp", "m3u8", "mp3", "m4a", "aac", "wav", "flac"]
    static let defaultGroup = "未分组"

    @Published private(set) var localItems: [MediaItem] = []
    @Published private(set) var remoteItems: [MediaItem] = []
    @Published var lastMessage: String?
    private let remoteKey = "remoteItems"

    var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var all: [MediaItem] { localItems + remoteItems }

    /// Remote items grouped by 电视台/分组, keeping first-seen order.
    var remoteGroups: [(name: String, items: [MediaItem])] {
        var order: [String] = []
        var map: [String: [MediaItem]] = [:]
        for item in remoteItems {
            let g = (item.group?.isEmpty == false ? item.group! : Library.defaultGroup)
            if map[g] == nil { order.append(g); map[g] = [] }
            map[g]!.append(item)
        }
        return order.map { ($0, map[$0]!) }
    }

    init() { reload() }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
        localItems = files
            .filter { Library.playableExts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MediaItem(url: $0, title: $0.deletingPathExtension().lastPathComponent, isRemote: false, group: nil, logo: nil) }
        if let data = UserDefaults.standard.data(forKey: remoteKey),
           let items = try? JSONDecoder().decode([MediaItem].self, from: data) {
            remoteItems = items
        }
        // .m3u / .txt playlists dropped into the Files folder are imported automatically
        for f in files where ["m3u", "txt"].contains(f.pathExtension.lowercased()) {
            if let text = Library.readText(f) {
                let parsed = PlaylistParser.parse(text)
                if !parsed.isEmpty {
                    merge(parsed)
                    try? FileManager.default.removeItem(at: f)
                }
            }
        }
    }

    static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: gb)
    }

    func importFile(_ src: URL) {
        let access = src.startAccessingSecurityScopedResource()
        defer { if access { src.stopAccessingSecurityScopedResource() } }
        let ext = src.pathExtension.lowercased()
        if ext == "m3u" || ext == "txt" {
            if let text = Library.readText(src) {
                let parsed = PlaylistParser.parse(text)
                merge(parsed)
                lastMessage = "导入了 \(parsed.count) 个频道"
            }
            return
        }
        let dest = uniqueDestination(for: src.lastPathComponent)
        try? FileManager.default.copyItem(at: src, to: dest)
        reload()
    }

    func uniqueDestination(for name: String) -> URL {
        var dest = documents.appendingPathComponent(name)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = documents.appendingPathComponent("\(base)-\(n).\(ext)")
            n += 1
        }
        return dest
    }

    func addRemote(name: String, url raw: String, group: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: s), url.scheme != nil else { lastMessage = "链接格式不对"; return }
        // A link to a playlist (m3u/txt) is treated as a subscription
        let ext = url.pathExtension.lowercased()
        if ext == "m3u" || ext == "txt" {
            subscribe(url)
            return
        }
        var title = name.trimmingCharacters(in: .whitespaces)
        if title.isEmpty {
            let n = url.deletingPathExtension().lastPathComponent
            title = n.isEmpty || n == "/" ? (url.host ?? s) : n
        }
        let g = group.trimmingCharacters(in: .whitespaces)
        remoteItems.append(MediaItem(url: url, title: title, isRemote: true, group: g.isEmpty ? nil : g, logo: nil))
        saveRemote()
    }

    /// Download an m3u / txt (DIYP) channel list and add its channels grouped by 台/分组.
    func subscribe(_ url: URL) {
        lastMessage = "正在读取频道列表…"
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let data = data else {
                    self.lastMessage = "读取失败：\(error?.localizedDescription ?? "无数据")"
                    return
                }
                let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
                let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: gb) ?? ""
                let parsed = PlaylistParser.parse(text)
                if parsed.isEmpty {
                    // Not a list: treat as a single stream
                    self.remoteItems.append(MediaItem(url: url, title: url.lastPathComponent, isRemote: true, group: nil, logo: nil))
                    self.saveRemote()
                    self.lastMessage = "已添加为单个链接"
                } else {
                    self.merge(parsed)
                    self.lastMessage = "导入了 \(parsed.count) 个频道"
                }
            }
        }.resume()
    }

    func merge(_ items: [MediaItem]) {
        let existing = Set(remoteItems.map { $0.url })
        remoteItems.append(contentsOf: items.filter { !existing.contains($0.url) })
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

    func deleteGroup(_ name: String) {
        remoteItems.removeAll { ($0.group?.isEmpty == false ? $0.group! : Library.defaultGroup) == name }
        saveRemote()
    }

    private func saveRemote() {
        if let data = try? JSONEncoder().encode(remoteItems) {
            UserDefaults.standard.set(data, forKey: remoteKey)
        }
    }
}

enum PlaylistParser {
    /// Supports #EXTM3U (group-title / tvg-name / tvg-logo) and the DIYP txt format ("央视,#genre#" then "CCTV1,http://...").
    static func parse(_ content: String) -> [MediaItem] {
        let lines = content.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if lines.contains(where: { $0.hasPrefix("#EXTINF") }) {
            return parseM3U(lines)
        }
        return parseTXT(lines)
    }

    private static func attr(_ name: String, in line: String) -> String? {
        guard let r = line.range(of: name + "=\"") else { return nil }
        let rest = line[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let v = String(rest[..<end]).trimmingCharacters(in: .whitespaces)
        return v.isEmpty ? nil : v
    }

    private static func parseM3U(_ lines: [String]) -> [MediaItem] {
        var result: [MediaItem] = []
        var title: String?
        var group: String?
        var logo: String?
        var extgrp: String?
        for line in lines where !line.isEmpty {
            if line.hasPrefix("#EXTINF") {
                group = attr("group-title", in: line)
                logo = attr("tvg-logo", in: line)
                var name: String?
                if let comma = lastCommaOutsideQuotes(line) {
                    name = String(line[line.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
                }
                if name == nil || name!.isEmpty { name = attr("tvg-name", in: line) }
                title = name
            } else if line.hasPrefix("#EXTGRP:") {
                extgrp = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("#") {
                continue
            } else if let url = URL(string: line), url.scheme != nil {
                let t = title ?? url.lastPathComponent
                result.append(MediaItem(url: url, title: t, isRemote: true, group: group ?? extgrp, logo: logo))
                title = nil; group = nil; logo = nil
            }
        }
        return result
    }

    private static func lastCommaOutsideQuotes(_ s: String) -> String.Index? {
        var inQuote = false
        var last: String.Index?
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "\"" { inQuote.toggle() }
            else if c == "," && !inQuote { last = i }
            i = s.index(after: i)
        }
        return last
    }

    private static func parseTXT(_ lines: [String]) -> [MediaItem] {
        var result: [MediaItem] = []
        var group: String?
        for line in lines where !line.isEmpty {
            guard let comma = line.firstIndex(of: ",") else { continue }
            let name = String(line[..<comma]).trimmingCharacters(in: .whitespaces)
            let rest = String(line[line.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
            if rest.hasPrefix("#genre#") { group = name; continue }
            // A line may hold several sources separated by '#'; take the first
            let first = rest.components(separatedBy: "#").first ?? rest
            if let url = URL(string: first), url.scheme != nil {
                result.append(MediaItem(url: url, title: name, isRemote: true, group: group, logo: nil))
            }
        }
        return result
    }
}
