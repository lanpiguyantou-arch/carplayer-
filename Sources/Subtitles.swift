import Foundation

struct SubtitleCue {
    let start: Double
    let end: Double
    let text: String
}

enum SRTParser {
    static func load(_ url: URL) -> [SubtitleCue] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: gb) ?? ""
        return parse(text)
    }

    static func parse(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for block in normalized.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map { String($0) }
            guard let idx = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let parts = lines[idx].components(separatedBy: "-->")
            guard parts.count == 2, let s = seconds(parts[0]), let e = seconds(parts[1]) else { continue }
            let body = lines[(idx + 1)...].joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            cues.append(SubtitleCue(start: s, end: e, text: body))
        }
        return cues
    }

    static func seconds(_ raw: String) -> Double? {
        let t = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let first = t.split(separator: " ").first.map { String($0) } ?? t
        let comps = first.split(separator: ":").map { String($0) }
        guard comps.count == 3, let h = Double(comps[0]), let m = Double(comps[1]), let s = Double(comps[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }
}
