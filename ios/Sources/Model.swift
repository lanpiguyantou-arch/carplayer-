import Foundation
import SwiftUI

struct Word: Hashable, Identifiable { let en: String; let zh: String; let unit: Int; var id: String { en } }
struct Line: Hashable, Codable {
    let en: String
    var zh: String
    var who: String {
        guard let r = en.range(of: "^[A-Z][A-Za-z ]{1,15}: ", options: .regularExpression) else { return "" }
        return String(en[r].dropLast(2))
    }
    var say: String { who.isEmpty ? en : String(en.dropFirst(who.count + 2)) }
}
struct Lesson: Identifiable { let n: Int; let title: String; let words: [Word]; let sentences: [Line]; let textTitle: String; let text: [Line]; var id: Int { n } }
struct MyText: Codable, Identifiable, Hashable { var id = UUID(); var title: String; var unit: Int; var lines: [Line] }
struct RState: Codable { var st: Int; var d: Int; var u: Int }

enum Data0 {
    static let units: [Lesson] = {
        guard let url = Bundle.main.url(forResource: "slb6s", withExtension: "json"),
              let d = try? Foundation.Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        func lines(_ a: Any?) -> [Line] { ((a as? [[String: String]]) ?? []).map { Line(en: $0["e"] ?? "", zh: $0["z"] ?? "") } }
        return arr.map { o in
            let n = o["n"] as? Int ?? 0
            let w = ((o["w"] as? [[String: String]]) ?? []).map { Word(en: $0["e"] ?? "", zh: $0["z"] ?? "", unit: n) }
            return Lesson(n: n, title: o["t"] as? String ?? "", words: w, sentences: lines(o["s"]), textTitle: o["xt"] as? String ?? "", text: lines(o["x"]))
        }
    }()
}

let curve = [1, 2, 4, 7, 15, 30]
func todayN() -> Int { Int((Date().timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT())) / 86400) }

final class Store: ObservableObject {
    static let shared = Store()
    private let ud = UserDefaults.standard
    @Published var speed: Double { didSet { ud.set(speed, forKey: "speed") } }
    @Published var accent: Int { didSet { ud.set(accent, forKey: "accent") } }   // 1 英音 2 美音
    @Published var engine: Int { didSet { ud.set(engine, forKey: "engine") } }   // 0 在线 1 系统
    @Published var showZh: Bool { didSet { ud.set(showZh, forKey: "showZh") } }
    @Published var zhRandom: Bool { didSet { ud.set(zhRandom, forKey: "zhRandom") } }
    @Published var zhShowText: Bool { didSet { ud.set(zhShowText, forKey: "zhShowText") } }
    @Published var wrong: Set<String> { didSet { ud.set(Array(wrong), forKey: "wrong") } }
    @Published var myTexts: [MyText] { didSet { save(myTexts, "myTexts") } }
    @Published var review: [String: RState] { didSet { save(review, "review") } }

    private init() {
        speed = ud.object(forKey: "speed") as? Double ?? 0.9
        accent = ud.object(forKey: "accent") as? Int ?? 1
        engine = ud.integer(forKey: "engine")
        showZh = ud.object(forKey: "showZh") as? Bool ?? true
        zhRandom = ud.object(forKey: "zhRandom") as? Bool ?? true
        zhShowText = ud.bool(forKey: "zhShowText")
        wrong = Set(ud.stringArray(forKey: "wrong") ?? [])
        myTexts = Store.load("myTexts") ?? []
        review = Store.load("review") ?? [:]
    }
    private func save<T: Encodable>(_ v: T, _ k: String) { if let d = try? JSONEncoder().encode(v) { ud.set(d, forKey: k) } }
    private static func load<T: Decodable>(_ k: String) -> T? {
        guard let d = UserDefaults.standard.data(forKey: k) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    // 遗忘曲线
    func inPlan(_ u: Lesson) -> Bool { u.words.first.map { review["w:" + $0.en] != nil } ?? false }
    func addToPlan(_ u: Lesson) {
        let t = todayN()
        for w in u.words where review["w:" + w.en] == nil { review["w:" + w.en] = RState(st: 0, d: t + 1, u: u.n) }
        for s in u.sentences where review["s:" + s.en] == nil { review["s:" + s.en] = RState(st: 0, d: t + 1, u: u.n) }
    }
    struct RItem: Identifiable { let key: String; let en: String; let zh: String; let isWord: Bool; let unit: Int; var id: String { key } }
    func lookup(_ key: String, _ unit: Int) -> RItem? {
        guard let u = Data0.units.first(where: { $0.n == unit }) else { return nil }
        let en = String(key.dropFirst(2))
        if key.hasPrefix("w:") { return u.words.first { $0.en == en }.map { RItem(key: key, en: $0.en, zh: $0.zh, isWord: true, unit: unit) } }
        return u.sentences.first { $0.en == en }.map { RItem(key: key, en: $0.en, zh: $0.zh, isWord: false, unit: unit) }
    }
    func dueItems() -> [RItem] {
        let t = todayN()
        return review.filter { $0.value.d <= t && $0.value.st < curve.count }
            .compactMap { lookup($0.key, $0.value.u) }
            .sorted { ($0.isWord ? 0 : 1, $0.unit, $0.key) < ($1.isWord ? 0 : 1, $1.unit, $1.key) }
    }
    func grade(_ key: String, ok: Bool) {
        guard var s = review[key] else { return }
        s.st = ok ? s.st + 1 : 0
        s.d = todayN() + (!ok ? 1 : (s.st >= curve.count ? 9999 : curve[s.st]))
        review[key] = s
    }
}

func norm(_ s: String) -> String {
    s.lowercased().replacingOccurrences(of: "’", with: "'").filter { !" .!?\n\t".contains($0) }
}

func splitEn(_ t: String) -> [String] {
    t.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.flatMap { row -> [String] in
        let marked = row.replacingOccurrences(of: "([.!?])\\s+(?=[A-Z\"'])", with: "$1\u{1}", options: .regularExpression)
        return marked.components(separatedBy: "\u{1}").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
func splitZh(_ t: String) -> [String] {
    t.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.flatMap { row -> [String] in
        let marked = row.replacingOccurrences(of: "([。！？!?])", with: "$1\u{1}", options: .regularExpression)
        return marked.components(separatedBy: "\u{1}").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

func translate(_ en: String) async -> String? {
    var c = URLComponents(string: "https://api.mymemory.translated.net/get")!
    c.queryItems = [URLQueryItem(name: "langpair", value: "en|zh-CN"), URLQueryItem(name: "q", value: en)]
    guard let url = c.url, let (d, _) = try? await URLSession.shared.data(from: url),
          let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let r = o["responseData"] as? [String: Any], let z = r["translatedText"] as? String, !z.isEmpty else { return nil }
    return z
}

@MainActor func translateMissing(_ id: UUID) async -> Int {
    let st = Store.shared
    guard let i = st.myTexts.firstIndex(where: { $0.id == id }) else { return 0 }
    var lines = st.myTexts[i].lines
    var ok = 0
    for k in lines.indices where lines[k].zh.isEmpty {
        if let z = await translate(lines[k].en) { lines[k].zh = z; ok += 1 }
    }
    if ok > 0, let j = st.myTexts.firstIndex(where: { $0.id == id }) { st.myTexts[j].lines = lines }
    return ok
}
