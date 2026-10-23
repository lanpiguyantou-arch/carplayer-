import Foundation

/// Adaptive diagnosis modelled on the upstream engine: up to 2 questions per topic.
/// 1st right → mastered (ancestors inferred mastered). 1st wrong → easier 2nd question:
/// right → shaky; wrong → weak and backtrack to its prerequisites (hard first).
final class DiagnosisSession: ObservableObject {
    let kg = KG.shared
    let targets: [String]
    let limit: Int
    @Published var current: (topic: String, question: Question, attempt: Int)?
    @Published var finished = false
    @Published private(set) var asked = 0
    private(set) var status: [String: Mastery] = [:]
    private(set) var inferred: Set<String> = []
    private var queue: [String] = []
    private var used: Set<String> = []

    init(targets: [String], limit: Int = 24) {
        self.targets = targets.filter { !(KG.shared.bank[$0] ?? []).isEmpty }
        self.limit = limit
        queue = self.targets
        advance()
    }

    private func pick(_ topic: String, easier than: Question? = nil) -> Question? {
        let list = (kg.bank[topic] ?? []).filter { !used.contains($0.id) }
        if let prev = than {
            return list.filter { $0.df <= prev.df }.min { $0.df < $1.df } ?? list.first
        }
        return list.min { $0.df < $1.df } ?? list.first
    }

    private func advance() {
        while let t = queue.first {
            queue.removeFirst()
            if status[t] != nil || inferred.contains(t) { continue }
            if asked >= limit { break }
            if let q = pick(t) { used.insert(q.id); current = (t, q, 1); return }
        }
        current = nil
        finished = true
    }

    func answer(_ ok: Bool) {
        guard let c = current else { return }
        asked += 1
        if ok {
            if c.attempt == 1 {
                status[c.topic] = .mastered
                inferred.formUnion(kg.ancestors(c.topic).filter { status[$0] == nil })
            } else {
                status[c.topic] = .shaky
            }
            advance()
        } else if c.attempt == 1, asked < limit, let q2 = pick(c.topic, easier: c.question) {
            used.insert(q2.id)
            current = (c.topic, q2, 2)
        } else {
            status[c.topic] = .weak
            let pre = (kg.prereqs[c.topic] ?? []).map { $0.id }.filter { status[$0] == nil && !inferred.contains($0) && !(kg.bank[$0] ?? []).isEmpty }
            queue.insert(contentsOf: pre, at: 0)
            advance()
        }
    }

    func skip() { answer(false) }

    var weak: [String] { sorted(status.filter { $0.value == .weak }.map { $0.key }) }
    var shaky: [String] { sorted(status.filter { $0.value == .shaky }.map { $0.key }) }
    var mastered: [String] { sorted(status.filter { $0.value == .mastered }.map { $0.key }) }
    var untested: [String] { targets.filter { status[$0] == nil && !inferred.contains($0) } }

    /// Weak topics none of whose prerequisites are weak.
    var roots: [String] {
        weak.filter { id in !(kg.prereqs[id] ?? []).contains { status[$0.id] == .weak } }
    }

    /// Learning path: weak + shaky topics, prerequisites first, by grade.
    var path: [String] {
        let set = Set(weak + shaky)
        var indeg: [String: Int] = [:]
        for id in set { indeg[id] = (kg.prereqs[id] ?? []).filter { set.contains($0.id) }.count }
        var ready = set.filter { indeg[$0] == 0 }
        var out: [String] = []
        while !ready.isEmpty {
            let id = ready.min { (kg.byId[$0]!.g, kg.index[$0]!) < (kg.byId[$1]!.g, kg.index[$1]!) }!
            ready.remove(id); out.append(id)
            for d in kg.dependents[id] ?? [] where set.contains(d) {
                indeg[d]! -= 1
                if indeg[d] == 0 { ready.insert(d) }
            }
        }
        return out
    }

    private func sorted(_ ids: [String]) -> [String] { ids.sorted { kg.index[$0]! < kg.index[$1]! } }
}
