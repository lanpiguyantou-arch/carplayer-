import Foundation

enum Verdict { case correct, wrong, manual }

enum Judge {
    static func normalize(_ s: String) -> String {
        var r = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [String: String] = ["，": ",", "、": ",", "；": ",", ";": ",", "（": "(", "）": ")", "－": "-", "−": "-", "＋": "+", "／": "/", "＝": "=", "’": "'", "‘": "'", "“": "", "”": "", "《": "", "》": "", "？": "", "！": "", "。": "", "：": ":", "％": "%", "×": "*", "÷": "/", "　": " "]
        for (k, v) in map { r = r.replacingOccurrences(of: k, with: v) }
        // full-width digits/letters
        r = r.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? r
        r = r.replacingOccurrences(of: " ", with: "")
        return r.lowercased()
    }

    static func number(_ s: String) -> Double? {
        var t = s.replacingOccurrences(of: "%", with: "")
        if t.hasPrefix("+") { t.removeFirst() }
        if let d = Double(t) { return d }
        let parts = t.split(separator: "/")
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 { return a / b }
        return nil
    }

    static func same(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if let x = number(a), let y = number(b) { return abs(x - y) < 1e-6 * max(1, abs(y)) }
        return false
    }

    static func judge(_ q: Question, _ input: String) -> Verdict {
        if q.ty == "self" { return .manual }
        if q.ty == "choice" { return input.uppercased() == q.a.uppercased() ? .correct : .wrong }
        let u = normalize(input)
        guard !u.isEmpty else { return .wrong }
        var refs = [q.a] + (q.ac ?? [])
        refs = refs.map(normalize)
        if q.ty == "spell" {
            let strip: (String) -> String = { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".!?")) }
            return refs.contains { strip($0) == strip(u) } ? .correct : .wrong
        }
        for r in refs {
            if q.pc == true {
                if same(u.replacingOccurrences(of: "%", with: ""), r.replacingOccurrences(of: "%", with: "")) { return .correct }
            }
            if same(u, r) { return .correct }
            let uParts = u.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            let rParts = r.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            if uParts.count > 1, uParts.count == rParts.count {
                if q.uo == true {
                    var pool = rParts
                    var ok = true
                    for p in uParts {
                        if let i = pool.firstIndex(where: { same(p, $0) }) { pool.remove(at: i) } else { ok = false; break }
                    }
                    if ok { return .correct }
                } else if zip(uParts, rParts).allSatisfy({ same($0, $1) }) { return .correct }
            }
        }
        if q.ty == "short" { return .manual }
        return .wrong
    }
}
