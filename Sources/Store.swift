import Foundation
import SwiftUI

enum Mastery: String, Codable {
    case mastered, shaky, weak
    var title: String { ["mastered": "已掌握", "shaky": "不稳", "weak": "薄弱"][rawValue]! }
    var color: Color { self == .mastered ? .green : self == .shaky ? .orange : .red }
}

struct WrongEntry: Codable, Identifiable, Hashable {
    var id: String { qid }
    let qid: String
    var count: Int
    var last: Date
    var myAnswer: String
}

final class Store: ObservableObject {
    static let shared = Store()
    @Published var mastery: [String: Mastery] = [:] { didSet { save() } }
    @Published var wrong: [String: WrongEntry] = [:] { didSet { save() } }
    @Published var answered: Int = 0 { didSet { save() } }
    @Published var correct: Int = 0 { didSet { save() } }
    @Published var subject: String = "math" { didSet { UserDefaults.standard.set(subject, forKey: "subject") } }

    private struct Snapshot: Codable { var mastery: [String: Mastery]; var wrong: [String: WrongEntry]; var answered: Int; var correct: Int }
    private var loading = true

    init() {
        if let d = UserDefaults.standard.data(forKey: "kgstore"), let s = try? JSONDecoder().decode(Snapshot.self, from: d) {
            mastery = s.mastery; wrong = s.wrong; answered = s.answered; correct = s.correct
        }
        subject = UserDefaults.standard.string(forKey: "subject") ?? "math"
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let s = Snapshot(mastery: mastery, wrong: wrong, answered: answered, correct: correct)
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: "kgstore") }
    }

    func record(_ q: Question, ok: Bool, answer: String) {
        answered += 1
        if ok {
            correct += 1
            if var w = wrong[q.id] { w.count = max(0, w.count - 1); wrong[q.id] = w.count == 0 ? nil : w }
        } else {
            var w = wrong[q.id] ?? WrongEntry(qid: q.id, count: 0, last: Date(), myAnswer: answer)
            w.count += 1; w.last = Date(); w.myAnswer = answer
            wrong[q.id] = w
        }
    }

    func progress(_ ids: [String]) -> (mastered: Int, total: Int) {
        (ids.filter { mastery[$0] == .mastered }.count, ids.count)
    }

    func resetAll() { mastery = [:]; wrong = [:]; answered = 0; correct = 0 }
}
