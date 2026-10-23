import SwiftUI

struct DiagnoseHomeView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("先问你选的知识点本身。答错再出一道同级或更容易的题，仍然错才沿着先修往回追，最后找出薄弱根因和补学顺序。")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Section { SubjectPicker(subject: $store.subject) }
                ForEach(KG.shared.volumes(Subject(rawValue: store.subject) ?? .math)) { v in
                    Section(v.name) {
                        NavigationLink { DiagnoseRunView(title: "\(v.name) 整册筛查", targets: v.units.flatMap { $0.topicIDs }, limit: 40) } label: {
                            Label("整册筛查", systemImage: "list.bullet.clipboard")
                        }
                        DisclosureGroup("按单元诊断") {
                            ForEach(v.units) { u in
                                NavigationLink(u.name) { DiagnoseRunView(title: u.name, targets: u.topicIDs) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("自适应诊断")
        }
    }
}

struct DiagnoseRunView: View {
    @EnvironmentObject var store: Store
    let title: String
    @StateObject private var session: DiagnosisSession
    @State private var answered = false
    @State private var lastOK = false

    init(title: String, targets: [String], limit: Int = 24) {
        self.title = title
        _session = StateObject(wrappedValue: DiagnosisSession(targets: targets, limit: limit))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let c = session.current {
                    HStack {
                        Text("已答 \(session.asked) 题").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        if c.attempt == 2 { Text("换一道再试").font(.caption).foregroundColor(.orange) }
                    }
                    QuestionCard(question: c.question) { ok, text in
                        store.record(c.question, ok: ok, answer: text)
                        lastOK = ok
                        answered = true
                    }
                    if answered {
                        Button("下一题") { answered = false; session.answer(lastOK) }
                            .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    }
                } else {
                    DiagnoseResultView(session: session)
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: session.finished) { f in
            guard f else { return }
            for id in session.mastered { store.mastery[id] = .mastered }
            for id in session.shaky { store.mastery[id] = .shaky }
            for id in session.weak { store.mastery[id] = .weak }
        }
    }
}

struct DiagnoseResultView: View {
    @ObservedObject var session: DiagnosisSession
    var body: some View {
        let kg = KG.shared
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                stat("掌握", session.mastered.count, .green)
                stat("不稳", session.shaky.count, .orange)
                stat("薄弱", session.weak.count, .red)
                stat("未测", session.untested.count, .gray)
            }
            if session.weak.isEmpty && session.shaky.isEmpty {
                Label("这部分都掌握了，继续往后学吧！", systemImage: "hand.thumbsup.fill").font(.headline).foregroundColor(.green)
            }
            if !session.roots.isEmpty {
                Text("薄弱根因").font(.headline)
                ForEach(session.roots, id: \.self) { id in
                    if let t = kg.byId[id] { topicRow(t, color: .red) }
                }
            }
            if !session.path.isEmpty {
                Text("建议补学顺序").font(.headline)
                ForEach(Array(session.path.enumerated()), id: \.element) { i, id in
                    if let t = kg.byId[id] {
                        HStack(alignment: .top) {
                            Text("\(i + 1)").bold().frame(width: 24)
                            topicRow(t, color: session.weak.contains(id) ? .red : .orange)
                        }
                    }
                }
            }
            if !session.untested.isEmpty {
                Text("题量已到上限，还有 \(session.untested.count) 个知识点没测，可以再诊断一次。").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func stat(_ name: String, _ n: Int, _ c: Color) -> some View {
        VStack { Text("\(n)").font(.title2.bold()).foregroundColor(c); Text(name).font(.caption) }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(c.opacity(0.1)))
    }

    private func topicRow(_ t: Topic, color: Color) -> some View {
        NavigationLink { TopicView(topic: t) } label: {
            HStack {
                Circle().fill(color).frame(width: 10, height: 10)
                VStack(alignment: .leading) {
                    Text(t.n).foregroundColor(.primary)
                    Text(t.v + " · " + t.u).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
        }
    }
}
