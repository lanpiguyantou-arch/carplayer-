import SwiftUI

struct WrongBookView: View {
    @EnvironmentObject var store: Store
    var entries: [WrongEntry] {
        store.wrong.values.filter { e in
            guard let q = KG.shared.questionById[e.qid], let t = KG.shared.byId[q.t] else { return false }
            return t.s == store.subject
        }.sorted { $0.last > $1.last }
    }
    var body: some View {
        NavigationStack {
            List {
                Section { SubjectPicker(subject: $store.subject) }
                if entries.isEmpty {
                    Text("还没有错题，继续保持！").foregroundColor(.secondary)
                } else {
                    Section {
                        NavigationLink {
                            PracticeView(title: "错题重练", questions: entries.compactMap { KG.shared.questionById[$0.qid] })
                        } label: { Label("全部重练（\(entries.count) 题）", systemImage: "arrow.counterclockwise") }
                    } footer: { Text("重练答对一次，错误次数减一，减到 0 自动移出。") }
                    Section {
                        ForEach(entries) { e in
                            if let q = KG.shared.questionById[e.qid] {
                                NavigationLink { PracticeView(title: "错题", questions: [q]) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(q.p).lineLimit(2)
                                        HStack {
                                            Text(KG.shared.byId[q.t]?.n ?? "").font(.caption).foregroundColor(.secondary)
                                            Spacer()
                                            Text("错 \(e.count) 次").font(.caption).foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { idx in idx.map { entries[$0].qid }.forEach { store.wrong[$0] = nil } }
                    }
                }
            }
            .navigationTitle("错题本")
        }
    }
}

struct MeView: View {
    @EnvironmentObject var store: Store
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            List {
                Section("学习统计") {
                    row("累计答题", "\(store.answered)")
                    row("正确率", store.answered == 0 ? "—" : "\(store.correct * 100 / store.answered)%")
                    row("错题", "\(store.wrong.count)")
                }
                Section("各科掌握") {
                    ForEach(Subject.allCases) { s in
                        let ids = KG.shared.topics.filter { $0.s == s.rawValue }.map { $0.id }
                        let p = store.progress(ids)
                        let weak = ids.filter { store.mastery[$0] == .weak }.count
                        HStack {
                            Label(s.title, systemImage: s.icon)
                            Spacer()
                            Text("掌握 \(p.mastered)/\(p.total)").foregroundColor(.secondary)
                            if weak > 0 { Text("薄弱 \(weak)").foregroundColor(.red) }
                        }
                    }
                }
                Section {
                    Button("清空学习记录", role: .destructive) { confirmReset = true }
                }
                Section("数据来源") {
                    Text("知识点、先修关系和题目来自 GitHub 开源项目「中小学知识图谱」（xiaoyang111222/cn-math-taxonomy），CC BY-NC 4.0 许可，仅供个人非商业学习使用。")
                        .font(.footnote).foregroundColor(.secondary)
                    Link("查看原项目", destination: URL(string: "https://github.com/xiaoyang111222/cn-math-taxonomy")!)
                }
            }
            .navigationTitle("我的")
            .confirmationDialog("确定清空所有掌握情况和错题吗？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.resetAll() }
            }
        }
    }
    private func row(_ a: String, _ b: String) -> some View { HStack { Text(a); Spacer(); Text(b).foregroundColor(.secondary) } }
}
