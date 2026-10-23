import SwiftUI

@main
struct SLBApp: App {
    @StateObject var store = Store.shared
    var body: some Scene {
        WindowGroup { NavigationStack { HomeView() }.environmentObject(store).tint(.blue) }
    }
}

let teal = Color(red: 0, green: 0.54, blue: 0.48)
let purple = Color(red: 0.37, green: 0.21, blue: 0.69)
let pink = Color(red: 0.85, green: 0.11, blue: 0.38)
let orange = Color(red: 0.98, green: 0.55, blue: 0)

struct BigButton: View {
    let title: String; var color: Color = .blue; let action: () -> Void
    init(_ t: String, _ c: Color = .blue, action: @escaping () -> Void) { title = t; color = c; self.action = action }
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(color).cornerRadius(12)
        }.buttonStyle(.plain)
    }
}

struct Card<C: View>: View {
    @ViewBuilder let content: C
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground)).cornerRadius(14)
    }
}

struct SpeedBar: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack {
            Text(String(format: "语速 %.1fx", store.speed)).font(.subheadline).frame(width: 80, alignment: .leading)
            Slider(value: $store.speed, in: 0.3...1.5, step: 0.1)
        }.padding(.horizontal).padding(.vertical, 6).background(Color(.systemBackground))
    }
}

struct Page<C: View>: View {
    let title: String
    @ViewBuilder let content: C
    var body: some View {
        VStack(spacing: 0) {
            SpeedBar()
            ScrollView { VStack(alignment: .leading, spacing: 10) { content }.padding() }
                .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .onDisappear { Speaker.shared.onDone = nil; Speaker.shared.stop() }
    }
}

struct HomeView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Page(title: "陕旅版英语 六年级上册") {
            NavigationLink { PlanView() } label: {
                Card {
                    Text("📅 今日复习（\(store.dueItems().count)）").font(.headline).foregroundColor(purple)
                    Text(store.review.isEmpty ? "按遗忘曲线安排单词和句子复习，先在单元里点“加入复习计划”" : "按遗忘曲线（1、2、4、7、15、30天）安排，点开看计划").font(.caption).foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            NavigationLink { ZhPickView() } label: {
                Card {
                    Text("中译英听写（全册）").font(.headline).foregroundColor(pink)
                    Text("念中文，孩子写英文；可选随机或顺序，可选单元").font(.caption).foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            NavigationLink { MyTextsView() } label: {
                Card {
                    Text("我的课文（拍照/粘贴添加）").font(.headline).foregroundColor(teal)
                    Text("拍课本自动识别英文，分句点读并翻译").font(.caption).foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            NavigationLink { WrongView() } label: {
                Card {
                    Text("错词本（\(store.wrong.count)）").font(.headline).foregroundColor(.red)
                    Text("听写和卡片里记错的词会自动收进来").font(.caption).foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            NavigationLink { SettingsView() } label: {
                Card {
                    Text("发音设置").font(.headline)
                    Text((store.engine == 0 ? "在线真人发音" : "手机系统语音") + " · " + (store.accent == 2 ? "美音" : "英音")).font(.caption).foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            ForEach(Data0.units) { u in
                NavigationLink { UnitView(u: u) } label: {
                    Card {
                        Text("Unit \(u.n)").font(.caption).foregroundColor(.blue)
                        Text(u.title).font(.headline)
                        Text("\(u.words.count) 个单词 · \(u.sentences.count) 个重点句").font(.caption).foregroundColor(.secondary)
                    }
                }.buttonStyle(.plain)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Form {
            Picker("发音来源", selection: $store.engine) { Text("在线真人发音（推荐）").tag(0); Text("手机系统语音（离线）").tag(1) }
            Picker("口音", selection: $store.accent) { Text("英音").tag(1); Text("美音").tag(2) }
            Button("试听：Hello, how are you?") { Speaker.shared.speak("Hello, how are you?") }
        }.navigationTitle("发音设置")
    }
}
