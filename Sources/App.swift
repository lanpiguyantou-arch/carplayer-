import SwiftUI

@main
struct KGStudyApp: App {
    @StateObject private var store = Store.shared
    var body: some Scene {
        WindowGroup {
            TabView {
                LearnView().tabItem { Label("学习", systemImage: "books.vertical") }
                DiagnoseHomeView().tabItem { Label("诊断", systemImage: "stethoscope") }
                WrongBookView().tabItem { Label("错题本", systemImage: "exclamationmark.bubble") }
                MeView().tabItem { Label("我的", systemImage: "person") }
            }
            .environmentObject(store)
        }
    }
}

struct SubjectPicker: View {
    @Binding var subject: String
    var body: some View {
        Picker("学科", selection: $subject) {
            ForEach(Subject.allCases) { Text($0.title).tag($0.rawValue) }
        }
        .pickerStyle(.segmented)
    }
}

struct MasteryDot: View {
    let m: Mastery?
    var body: some View {
        Circle().fill(m?.color ?? Color.gray.opacity(0.3)).frame(width: 10, height: 10)
    }
}

struct LearnView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        NavigationStack {
            List {
                Section { SubjectPicker(subject: $store.subject) }
                ForEach(KG.shared.volumes(Subject(rawValue: store.subject) ?? .math)) { v in
                    let ids = v.units.flatMap { $0.topicIDs }
                    let p = store.progress(ids)
                    NavigationLink { VolumeView(volume: v) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(v.name).font(.headline)
                                Text("\(v.units.count) 个单元 · \(ids.count) 个知识点").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            ProgressRing(value: p.total == 0 ? 0 : Double(p.mastered) / Double(p.total))
                        }
                    }
                }
            }
            .navigationTitle("中小学知识图谱")
        }
    }
}

struct ProgressRing: View {
    let value: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4)
            Circle().trim(from: 0, to: value).stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))%").font(.system(size: 10))
        }
        .frame(width: 38, height: 38)
    }
}

struct VolumeView: View {
    @EnvironmentObject var store: Store
    let volume: Volume
    var body: some View {
        List {
            ForEach(volume.units) { u in
                Section {
                    ForEach(u.topicIDs, id: \.self) { id in
                        if let t = KG.shared.byId[id] {
                            NavigationLink { TopicView(topic: t) } label: {
                                HStack { MasteryDot(m: store.mastery[id]); Text(t.n) }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(u.name)
                        Spacer()
                        NavigationLink { PracticeView(title: u.name, questions: practiceSet(u.topicIDs)) } label: { Text("练本单元").font(.caption) }
                        NavigationLink { DiagnoseRunView(title: u.name, targets: u.topicIDs) } label: { Text("诊断").font(.caption) }
                    }
                }
            }
        }
        .navigationTitle(volume.name)
    }
}

func practiceSet(_ topicIDs: [String], perTopic: Int = 2) -> [Question] {
    topicIDs.flatMap { Array((KG.shared.bank[$0] ?? []).shuffled().prefix(perTopic)) }
}

struct TopicView: View {
    @EnvironmentObject var store: Store
    let topic: Topic
    var body: some View {
        let kg = KG.shared
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(topic.n).font(.title2.bold())
                    Text("\(topic.v) · \(topic.u)").font(.caption).foregroundColor(.secondary)
                    if let m = store.mastery[topic.id] {
                        Text(m.title).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 3).background(m.color.opacity(0.2)).foregroundColor(m.color).clipShape(Capsule())
                    }
                    if !topic.de.isEmpty { Text(topic.de) }
                }
                .padding(.vertical, 4)
            }
            if !topic.mc.isEmpty {
                Section("掌握标准") { ForEach(topic.mc, id: \.self) { Label($0, systemImage: "checkmark.circle") } }
            }
            Section {
                NavigationLink { PracticeView(title: topic.n, questions: (kg.bank[topic.id] ?? []).sorted { $0.df < $1.df }) } label: {
                    Label("练习（\(kg.bank[topic.id]?.count ?? 0) 题）", systemImage: "pencil")
                }
                NavigationLink { DiagnoseRunView(title: topic.n, targets: [topic.id]) } label: {
                    Label("诊断：沿先修往回找根因", systemImage: "stethoscope")
                }
            }
            if let pre = kg.prereqs[topic.id], !pre.isEmpty {
                Section("先学这些（先修）") {
                    ForEach(pre, id: \.self) { p in
                        if let t = kg.byId[p.id] {
                            NavigationLink { TopicView(topic: t) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack { MasteryDot(m: store.mastery[p.id]); Text(t.n); if !p.hard { Text("参考").font(.caption2).foregroundColor(.secondary) } }
                                    Text("\(t.v) · \(p.reason)").font(.caption).foregroundColor(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
            if let next = kg.dependents[topic.id], !next.isEmpty {
                Section("学完可以学") {
                    ForEach(next, id: \.self) { id in
                        if let t = kg.byId[id] {
                            NavigationLink { TopicView(topic: t) } label: { HStack { MasteryDot(m: store.mastery[id]); Text(t.n); Spacer(); Text(t.v).font(.caption).foregroundColor(.secondary) } }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
