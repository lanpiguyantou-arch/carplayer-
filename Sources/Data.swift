import Foundation

struct Topic: Codable, Identifiable, Hashable {
    let id: String
    let n: String      // name
    let s: String      // subject
    let g: Int         // grade
    let v: String      // volume, e.g. 七上
    let u: String      // unit / chapter
    let dm: String
    let de: String
    let mc: [String]
}

struct Dep: Codable { let t: String; let p: String; let h: Bool; let r: String }

struct Choice: Codable, Hashable { let k: String; let x: String; let f: String? }

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let t: String
    let df: Int
    let ty: String
    let p: String
    let a: String
    let ex: String
    let c: [Choice]?
    let f: String?
    let ac: [String]?
    let uo: Bool?
    let pc: Bool?
    let hc: Bool?
}

struct Prereq: Hashable { let id: String; let hard: Bool; let reason: String }

struct Volume: Identifiable, Hashable {
    var id: String { subject + "|" + name }
    let subject: String
    let name: String
    let grade: Int
    var units: [ChapterUnit]
}

struct ChapterUnit: Identifiable, Hashable {
    var id: String { volume + "|" + name }
    let volume: String
    let name: String
    var topicIDs: [String]
}

enum Subject: String, CaseIterable, Identifiable {
    case chinese, math, english, physics
    var id: String { rawValue }
    var title: String { ["chinese": "语文", "math": "数学", "english": "英语", "physics": "物理"][rawValue]! }
    var icon: String { ["chinese": "text.book.closed", "math": "function", "english": "character.book.closed", "physics": "atom"][rawValue]! }
}

final class KG {
    static let shared = KG()
    let topics: [Topic]
    let byId: [String: Topic]
    let index: [String: Int]
    let prereqs: [String: [Prereq]]
    let dependents: [String: [String]]
    let bank: [String: [Question]]
    let questionById: [String: Question]
    let volumes: [Volume]

    private init() {
        struct Bundle_: Codable { let topics: [Topic]; let deps: [Dep]; let questions: [Question] }
        let url = Bundle.main.url(forResource: "kgdata", withExtension: "json")!
        let b = try! JSONDecoder().decode(Bundle_.self, from: Data(contentsOf: url))
        topics = b.topics
        var by: [String: Topic] = [:], idx: [String: Int] = [:]
        for (i, t) in b.topics.enumerated() { by[t.id] = t; idx[t.id] = i }
        byId = by; index = idx
        var pre: [String: [Prereq]] = [:], dep: [String: [String]] = [:]
        var seen = Set<String>()
        for d in b.deps where by[d.t] != nil && by[d.p] != nil {
            if !seen.insert(d.t + "<" + d.p).inserted { continue }
            pre[d.t, default: []].append(Prereq(id: d.p, hard: d.h, reason: d.r))
            dep[d.p, default: []].append(d.t)
        }
        for k in pre.keys { pre[k]!.sort { ($0.hard ? 0 : 1, idx[$0.id]!) < ($1.hard ? 0 : 1, idx[$1.id]!) } }
        prereqs = pre; dependents = dep
        var bk: [String: [Question]] = [:], qb: [String: Question] = [:]
        for q in b.questions { bk[q.t, default: []].append(q); qb[q.id] = q }
        bank = bk; questionById = qb
        var vols: [Volume] = []
        var vIdx: [String: Int] = [:]
        for t in b.topics {
            let key = t.s + "|" + t.v
            if vIdx[key] == nil { vIdx[key] = vols.count; vols.append(Volume(subject: t.s, name: t.v, grade: t.g, units: [])) }
            let vi = vIdx[key]!
            if let ui = vols[vi].units.firstIndex(where: { $0.name == t.u }) { vols[vi].units[ui].topicIDs.append(t.id) }
            else { vols[vi].units.append(ChapterUnit(volume: t.v, name: t.u, topicIDs: [t.id])) }
        }
        volumes = vols
    }

    func volumes(_ s: Subject) -> [Volume] { volumes.filter { $0.subject == s.rawValue } }

    private var ancMemo: [String: Set<String>] = [:]
    func ancestors(_ id: String) -> Set<String> {
        if let m = ancMemo[id] { return m }
        var out = Set<String>()
        for p in prereqs[id] ?? [] { out.insert(p.id); out.formUnion(ancestors(p.id)) }
        ancMemo[id] = out
        return out
    }
}
