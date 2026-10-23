import SwiftUI

struct UnitView: View {
    @EnvironmentObject var store: Store
    let u: Lesson
    @State private var toast = ""
    var body: some View {
        Page(title: "Unit \(u.n)") {
            Text(u.title).font(.title3.bold())
            BigButton(store.inPlan(u) ? "📅 已在复习计划中（查看）" : "📅 学完了，加入遗忘曲线复习计划", purple) {
                if !store.inPlan(u) { store.addToPlan(u); toast = "已加入：\(u.words.count) 个单词 + \(u.sentences.count) 个句子，明天开始复习" }
            }
            if !toast.isEmpty { Text(toast).font(.caption).foregroundColor(purple) }
            Card {
                Text("课本课文 Part A / Part B").font(.headline).foregroundColor(teal)
                Text("拍一下课本那一页，自动识别英文、翻译，然后点读").font(.caption).foregroundColor(.secondary)
                ForEach(store.myTexts.filter { $0.unit == u.n }) { t in
                    NavigationLink { PointReadView(title: "Unit \(u.n) 课文", sub: t.title, textID: t.id, fixed: []) } label: {
                        Text("📖 " + t.title).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(teal).cornerRadius(12)
                    }.buttonStyle(.plain)
                }
                HStack {
                    NavigationLink { AddTextView(unit: u.n, preTitle: "Unit \(u.n) Part A") } label: { pill("📷 添加 Part A") }.buttonStyle(.plain)
                    NavigationLink { AddTextView(unit: u.n, preTitle: "Unit \(u.n) Part B") } label: { pill("📷 添加 Part B") }.buttonStyle(.plain)
                }
            }
            NavigationLink { PointReadView(title: "Unit \(u.n) 情景对话", sub: u.textTitle, textID: nil, fixed: u.text) } label: { pill("💬 单元情景对话（\(u.textTitle)，带翻译）") }.buttonStyle(.plain)
            NavigationLink { WordsView(words: u.words, title: "Unit \(u.n) 单词") } label: { pill("① 单词表（点读）", .blue) }.buttonStyle(.plain)
            NavigationLink { SentencesView(u: u) } label: { pill("② 重点句（正常 / 慢速 / 循环跟读）", .blue) }.buttonStyle(.plain)
            NavigationLink { CardsView(words: u.words.shuffled()) } label: { pill("③ 记忆卡片（看中文想英文）", .green) }.buttonStyle(.plain)
            NavigationLink { DictationView(words: u.words.shuffled()) } label: { pill("④ 听音拼写（听写）", orange) }.buttonStyle(.plain)
            NavigationLink { ZhSetupView(words: u.words, title: "Unit \(u.n) 中译英听写") } label: { pill("⑤ 中译英听写（念中文写英文）", pink) }.buttonStyle(.plain)
            BigButton("⑥ 连续播放全部单词", purple) { playAll(u.words.map { $0.en }) }
        }
    }
    func pill(_ t: String, _ c: Color = teal) -> some View {
        Text(t).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(c).cornerRadius(12)
    }
}

func playAll(_ list: [String], from i: Int = 0) {
    guard i < list.count else { Speaker.shared.onDone = nil; return }
    Speaker.shared.onDone = { DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { if Speaker.shared.onDone != nil { playAll(list, from: i + 1) } } }
    Speaker.shared.speak(list[i])
}

struct WordsView: View {
    let words: [Word]; let title: String
    var body: some View {
        Page(title: title) {
            Text("点单词听发音，长按慢速读").font(.caption).foregroundColor(.secondary)
            ForEach(words) { w in
                Card {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(w.en).font(.title3.bold()).foregroundColor(Color(red: 0.05, green: 0.28, blue: 0.63))
                            Text(w.zh).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill").foregroundColor(.blue)
                    }
                }
                .onTapGesture { Speaker.shared.onDone = nil; Speaker.shared.speak(w.en) }
                .onLongPressGesture { Speaker.shared.onDone = nil; Speaker.shared.speak(w.en, slow: true) }
            }
        }
    }
}

struct SentencesView: View {
    @EnvironmentObject var store: Store
    let u: Lesson
    @State private var looping: String? = nil
    var body: some View {
        Page(title: "Unit \(u.n) 重点句") {
            Text("“循环”会一遍遍慢速重复，方便跟读；再点一次停止。").font(.caption).foregroundColor(.secondary)
            ForEach(u.sentences, id: \.en) { s in
                Card {
                    Text(s.en).font(.headline)
                    if store.showZh && !s.zh.isEmpty { Text(s.zh).font(.subheadline).foregroundColor(.secondary) }
                    HStack {
                        small("▶ 正常", .blue) { looping = nil; Speaker.shared.onDone = nil; Speaker.shared.speak(s.en) }
                        small("🐢 慢速", .green) { looping = nil; Speaker.shared.onDone = nil; Speaker.shared.speak(s.en, slow: true) }
                        small(looping == s.en ? "⏹ 停止" : "🔁 循环", purple) {
                            if looping == s.en { looping = nil; Speaker.shared.onDone = nil; Speaker.shared.stop() }
                            else { looping = s.en; loop(s.en) }
                        }
                    }
                }
            }
        }
    }
    func loop(_ t: String) {
        Speaker.shared.onDone = { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if looping == t { loop(t) } } }
        Speaker.shared.speak(t, slow: true)
    }
    func small(_ t: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Text(t).font(.subheadline.bold()).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(c).cornerRadius(10) }.buttonStyle(.plain)
    }
}

struct PointReadView: View {
    @EnvironmentObject var store: Store
    let title: String; let sub: String; let textID: UUID?; let fixed: [Line]
    @State private var cur = -1
    @State private var msg = ""
    var lines: [Line] { if let id = textID { return store.myTexts.first { $0.id == id }?.lines ?? [] } else { return fixed } }
    var body: some View {
        VStack(spacing: 0) {
            SpeedBar()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(sub).font(.title3.bold())
                        Text("点一句读一句，长按这句慢速读。").font(.caption).foregroundColor(.secondary)
                        HStack {
                            BigButton("▶ 全文连读") { readFrom(0, slow: false, proxy) }
                            BigButton("🐢 慢速连读", .green) { readFrom(0, slow: true, proxy) }
                            BigButton("⏹", .red) { Speaker.shared.onDone = nil; Speaker.shared.stop(); cur = -1 }.frame(width: 64)
                        }
                        Toggle("显示中文翻译", isOn: $store.showZh)
                        if !msg.isEmpty { Text(msg).font(.caption).foregroundColor(teal) }
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                            VStack(alignment: .leading, spacing: 4) {
                                if !l.who.isEmpty { Text(l.who).font(.caption.bold()).foregroundColor(orange) }
                                Text(l.say).font(.title3.bold()).foregroundColor(Color(red: 0.05, green: 0.28, blue: 0.63))
                                if store.showZh { Text(l.zh.isEmpty ? "（翻译中…）" : l.zh).foregroundColor(.secondary) }
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(i == cur ? Color.blue.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(i == cur ? Color.blue : .clear, lineWidth: 2))
                            .cornerRadius(14).id(i)
                            .onTapGesture { Speaker.shared.onDone = nil; cur = i; Speaker.shared.speak(l.say) }
                            .onLongPressGesture { Speaker.shared.onDone = nil; cur = i; Speaker.shared.speak(l.say, slow: true) }
                        }
                    }.padding()
                }.background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .onDisappear { Speaker.shared.onDone = nil; Speaker.shared.stop() }
        .task {
            if let id = textID, lines.contains(where: { $0.zh.isEmpty }) {
                let n = await translateMissing(id)
                msg = n > 0 ? "已自动翻译 \(n) 句" : "自动翻译失败，请检查网络"
            }
        }
    }
    func readFrom(_ i: Int, slow: Bool, _ proxy: ScrollViewProxy) {
        let ls = lines
        guard i < ls.count else { Speaker.shared.onDone = nil; cur = -1; return }
        cur = i
        withAnimation { proxy.scrollTo(i, anchor: .center) }
        Speaker.shared.onDone = { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if Speaker.shared.onDone != nil { readFrom(i + 1, slow: slow, proxy) } } }
        Speaker.shared.speak(ls[i].say, slow: slow)
    }
}
