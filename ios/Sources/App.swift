import SwiftUI

@main
struct DDFZApp: App {
    @StateObject var store = Store.shared
    init() { Listener.ask() }
    var body: some Scene {
        WindowGroup { NavigationStack { HomeView() }.environmentObject(store).tint(brand) }
    }
}

let brand = Color(red: 0.78, green: 0.16, blue: 0.16)
let purple = Color(red: 0.37, green: 0.21, blue: 0.69)
let teal = Color(red: 0, green: 0.54, blue: 0.48)
let orange = Color(red: 0.98, green: 0.55, blue: 0)

struct BigButton: View {
    let title: String; var color: Color; let action: () -> Void
    init(_ t: String, _ c: Color = .blue, action: @escaping () -> Void) { title = t; color = c; self.action = action }
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(color).cornerRadius(12)
        }.buttonStyle(.plain)
    }
}

struct Card<C: View>: View {
    var color: Color = Color(.secondarySystemGroupedBackground)
    @ViewBuilder let content: C
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(color).cornerRadius(14)
    }
}

struct QuizSpec: Hashable { let items: [Item]; let title: String; let review: Bool }
enum Route: Hashable { case lesson(Int), quiz(QuizSpec), wrong, settings }

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var path: QuizSpec?
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("题目会读出来，读到横线处请孩子说出答案。").font(.subheadline).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                let due = store.dueItems
                NavigationLink(value: Route.quiz(QuizSpec(items: due, title: "今日复习", review: true))) {
                    Card(color: Color.purple.opacity(0.12)) {
                        Text("📅 今日复习（\(due.count)）").font(.title3.bold()).foregroundColor(purple)
                        Text("错题按 1-2-4-7-15-30 天遗忘曲线回来复习").font(.footnote).foregroundColor(.gray)
                    }
                }.disabled(due.isEmpty)
                NavigationLink(value: Route.wrong) {
                    Card(color: Color.red.opacity(0.10)) {
                        Text("📕 错题本（\(store.wrongItems.count)）").font(.title3.bold()).foregroundColor(.red)
                        Text("已牢记 \(store.mastered) 题 · 查看和重练").font(.footnote).foregroundColor(.gray)
                    }
                }
                NavigationLink(value: Route.quiz(QuizSpec(items: Array(Bank.all.shuffled().prefix(10)), title: "全册随机", review: false))) {
                    Card(color: Color.green.opacity(0.12)) {
                        Text("🎲 全册随机 10 题").font(.title3.bold()).foregroundColor(.green)
                        Text("填空和问答混合抽问").font(.footnote).foregroundColor(.gray)
                    }
                }
                Text("课程").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                ForEach(Bank.lessons) { l in
                    NavigationLink(value: Route.lesson(l.id)) {
                        Card {
                            Text("第\(l.id)课  \(l.title)").font(.headline).foregroundColor(.primary)
                            Text("填空 \(l.items.filter { $0.isFill }.count) · 问答 \(l.items.filter { !$0.isFill }.count)").font(.footnote).foregroundColor(.gray)
                        }
                    }
                }
                NavigationLink(value: Route.settings) { Card { Text("⚙ 设置").font(.headline).foregroundColor(.primary) } }
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("道法六上 · 问答")
        .navigationDestination(for: Route.self) { r in
            switch r {
            case .lesson(let id): if let l = Bank.lessons.first(where: { $0.id == id }) { LessonView(l: l) }
            case .quiz(let q): QuizView(spec: q)
            case .wrong: WrongView()
            case .settings: SettingsView()
            }
        }
    }
}

struct LessonView: View {
    let l: LessonData
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                let fills = l.items.filter { $0.isFill }; let qas = l.items.filter { !$0.isFill }
                HStack {
                    NavigationLink(value: Route.quiz(QuizSpec(items: l.items, title: "第\(l.id)课", review: false))) { Pill("▶ 按顺序全部", brand) }
                    NavigationLink(value: Route.quiz(QuizSpec(items: l.items.shuffled(), title: "第\(l.id)课 随机", review: false))) { Pill("🎲 随机问", .green) }
                }
                HStack {
                    NavigationLink(value: Route.quiz(QuizSpec(items: fills, title: "第\(l.id)课 填空", review: false))) { Pill("✏ 只问填空(\(fills.count))", .blue) }
                    NavigationLink(value: Route.quiz(QuizSpec(items: qas, title: "第\(l.id)课 问答", review: false))) { Pill("💬 只问问答(\(qas.count))", teal) }
                }
                ForEach(Array(l.items.enumerated()), id: \.element.id) { k, it in
                    NavigationLink(value: Route.quiz(QuizSpec(items: Array(l.items.dropFirst(k)), title: "第\(l.id)课", review: false))) {
                        Card { Text((it.isFill ? "✏ 填空  " : "💬 问答  ") + it.q).foregroundColor(.primary).multilineTextAlignment(.leading) }
                    }
                }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle(l.title)
    }
}

struct Pill: View {
    let t: String; let c: Color
    init(_ t: String, _ c: Color) { self.t = t; self.c = c }
    var body: some View { Text(t).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(c).cornerRadius(12) }
}

struct WrongView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                let list = store.wrongItems
                if list.isEmpty { Text("还没有错题，继续加油！").font(.title3).padding(.top, 30) }
                else {
                    NavigationLink(value: Route.quiz(QuizSpec(items: list.shuffled(), title: "错题重练", review: true))) { Pill("▶ 把错题全部练一遍（\(list.count)）", .red) }
                    ForEach(list) { it in
                        Card {
                            Text("第\(it.lesson)课 · \(it.isFill ? "填空" : "问答") · 错 \(store.review[it.id]?["w"] ?? 0) 次 · 进度 \(store.review[it.id]?["st"] ?? 0)/6").font(.caption).foregroundColor(.gray)
                            Text(it.q).font(.headline)
                            Text("答案：" + (it.isFill ? it.blanks.joined(separator: "、") : it.a)).foregroundColor(.green)
                            if !it.memory.isEmpty { Text("🧠 " + it.memory).foregroundColor(purple).font(.subheadline) }
                        }.onTapGesture { Speaker.shared.speak(it.answerText) }
                    }
                    Button("清空错题本", role: .destructive) { store.review = [:] }.padding(.top, 20)
                }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("错题本")
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Form {
            Section("朗读声音") {
                Picker("声音", selection: $store.engine) { Text("在线真人发音").tag(0); Text("系统语音").tag(1) }.pickerStyle(.segmented)
                HStack { Text(String(format: "语速 %.1f", store.speed)); Slider(value: $store.speed, in: 0.6...1.6, step: 0.1) }
                Button("试听") { Speaker.shared.speak("法律规范着我们的行为，保护着我们的权利。") }
            }
            Section("收音") {
                Toggle("用麦克风识别孩子的回答", isOn: $store.useMic)
                Picker("等待开口", selection: $store.waitSec) { ForEach([10, 15, 20, 30], id: \.self) { Text("\($0) 秒").tag($0) } }
                Text("超过等待时间没开口，会问要不要看答案。").font(.footnote).foregroundColor(.gray)
            }
        }.navigationTitle("设置")
    }
}
