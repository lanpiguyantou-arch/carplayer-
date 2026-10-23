import SwiftUI

struct CardsView: View {
    @EnvironmentObject var store: Store
    let words: [Word]
    @State private var i = 0
    @State private var show = false
    @State private var known = 0
    var body: some View {
        Page(title: "记忆卡片") {
            if i >= words.count {
                Text("完成！记住 \(known) / \(words.count)").font(.title2.bold()).foregroundColor(.green).padding(.top, 30)
                BigButton("再来一遍") { i = 0; known = 0; show = false }
            } else {
                let w = words[i]
                Text("\(i + 1) / \(words.count)").foregroundColor(.secondary)
                Card {
                    Text(w.zh).font(.largeTitle.bold()).frame(maxWidth: .infinity).padding(.vertical, 20)
                    if show { Text(w.en).font(.title.bold()).foregroundColor(.blue).frame(maxWidth: .infinity) }
                }
                if !show { BigButton("👀 翻面看英文") { show = true; Speaker.shared.speak(w.en) } }
                else {
                    BigButton("🔊 再听一遍", .gray) { Speaker.shared.speak(w.en) }
                    HStack {
                        BigButton("✓ 记住了", .green) { known += 1; store.wrong.remove(w.en); next() }
                        BigButton("✗ 没记住", .red) { store.wrong.insert(w.en); next() }
                    }
                }
            }
        }
    }
    func next() { i += 1; show = false }
}

struct DictationView: View {
    @EnvironmentObject var store: Store
    let words: [Word]
    @State private var i = 0
    @State private var right = 0
    @State private var input = ""
    @State private var result = ""
    @State private var ok = false
    @State private var checked = false
    @FocusState private var focus: Bool
    var body: some View {
        Page(title: "听音拼写") {
            if i >= words.count {
                Text("听写完成！正确 \(right) / \(words.count)").font(.title2.bold()).foregroundColor(.green).padding(.top, 30)
                BigButton("再听写一遍") { i = 0; right = 0; reset() }
            } else {
                let w = words[i]
                Text("\(i + 1) / \(words.count)    提示：\(w.zh)").foregroundColor(.secondary)
                HStack {
                    BigButton("🔊 再听一遍") { Speaker.shared.speak(w.en) }
                    BigButton("🐢 慢速", .green) { Speaker.shared.speak(w.en, slow: true) }
                }
                TextField("在这里拼写英文", text: $input).font(.title2).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(Color(.systemBackground)).cornerRadius(10).focused($focus).onSubmit { check(w) }
                if !result.isEmpty { Text(result).font(.title3.bold()).foregroundColor(ok ? .green : .red) }
                BigButton(checked ? (i + 1 >= words.count ? "看结果" : "下一个") : "提交") { check(w) }
            }
        }
        .onAppear { sayCurrent() }
        .onChange(of: i) { _ in sayCurrent() }
    }
    func sayCurrent() { if i < words.count { let w = words[i]; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Speaker.shared.speak(w.en); focus = true } } }
    func reset() { input = ""; result = ""; checked = false; ok = false }
    func check(_ w: Word) {
        if checked { reset(); i += 1; return }
        checked = true
        if norm(input) == norm(w.en) { right += 1; ok = true; result = "✓ 正确：\(w.en)"; store.wrong.remove(w.en) }
        else { ok = false; result = "✗ 正确拼写：\(w.en)\n你写的：\(input)"; store.wrong.insert(w.en) }
    }
}

struct ZhPickView: View {
    @State private var sel = Set(Data0.units.map { $0.n })
    var body: some View {
        Page(title: "中译英听写 · 选单元") {
            HStack {
                BigButton("全选", .gray) { sel = Set(Data0.units.map { $0.n }) }
                BigButton("全不选", .gray) { sel = [] }
            }
            ForEach(Data0.units) { u in
                Button { if sel.contains(u.n) { sel.remove(u.n) } else { sel.insert(u.n) } } label: {
                    HStack {
                        Image(systemName: sel.contains(u.n) ? "checkmark.square.fill" : "square").foregroundColor(pink)
                        Text("Unit \(u.n)  \(u.title)（\(u.words.count) 词）").foregroundColor(.primary)
                        Spacer()
                    }.padding(.vertical, 4)
                }
            }
            let ws = Data0.units.filter { sel.contains($0.n) }.flatMap { $0.words }
            if ws.isEmpty { Text("至少选一个单元").foregroundColor(.secondary) }
            else {
                NavigationLink { ZhSetupView(words: ws, title: "中译英听写") } label: {
                    Text("下一步（\(ws.count) 词）").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(pink).cornerRadius(12)
                }.buttonStyle(.plain)
            }
        }
    }
}

struct ZhSetupView: View {
    @EnvironmentObject var store: Store
    let words: [Word]; let title: String
    var body: some View {
        Page(title: title) {
            Text("共 \(words.count) 个单词/短语").foregroundColor(.secondary)
            Text("出题顺序").font(.headline).padding(.top, 8)
            Picker("出题顺序", selection: $store.zhRandom) { Text("随机模式").tag(true); Text("顺序模式").tag(false) }.pickerStyle(.segmented)
            Toggle("屏幕上也显示中文（关掉就只听不看）", isOn: $store.zhShowText).padding(.top, 8)
            Text("可以在手机上输入英文自动判对错，也可以写在纸上，点“看答案”后自己判。").font(.caption).foregroundColor(.secondary)
            NavigationLink { ZhDictationView(words: store.zhRandom ? words.shuffled() : words, title: title) } label: {
                Text("开始听写").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(pink).cornerRadius(12)
            }.buttonStyle(.plain).padding(.top, 8)
        }
    }
}

struct ZhDictationView: View {
    @EnvironmentObject var store: Store
    @State var words: [Word]
    let title: String
    @State private var i = 0
    @State private var right = 0
    @State private var wrongList: [Word] = []
    @State private var input = ""
    @State private var revealed = false
    @State private var showZh = false
    @State private var result = ""
    @State private var resColor = Color.blue
    @State private var selfJudge = false
    var body: some View {
        Page(title: title + (store.zhRandom ? "（随机）" : "（顺序）")) {
            if i >= words.count {
                Text("听写完成！写对 \(right) / \(words.count)").font(.title2.bold()).foregroundColor(.green).padding(.top, 30)
                if !wrongList.isEmpty {
                    Text("写错的：").font(.headline).foregroundColor(.red)
                    ForEach(wrongList) { w in Text("\(w.en)   \(w.zh)") }
                    BigButton("只练写错的", .red) { restart(wrongList) }
                }
                BigButton("再来一遍") { restart(store.zhRandom ? words.shuffled() : words) }
            } else {
                let w = words[i]
                Text("第 \(i + 1) / \(words.count) 个").foregroundColor(.secondary)
                if showZh || store.zhShowText || revealed { Text(w.zh).font(.largeTitle.bold()).foregroundColor(pink) }
                HStack {
                    BigButton("🔊 再念一遍中文") { Speaker.shared.speakZh(w.zh) }
                    BigButton("👀 看中文", .gray) { showZh = true }.frame(width: 110)
                }
                TextField("输入英文（写在纸上可以不填）", text: $input).font(.title2).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(Color(.systemBackground)).cornerRadius(10).onSubmit { reveal(w) }
                if !result.isEmpty { Text(result).font(.title3.bold()).foregroundColor(resColor) }
                if selfJudge {
                    HStack {
                        BigButton("✓ 写对了", .green) { right += 1; store.wrong.remove(w.en); next() }
                        BigButton("✗ 写错了", .red) { wrongList.append(w); store.wrong.insert(w.en); next() }
                    }
                } else {
                    BigButton(revealed ? (i + 1 >= words.count ? "看结果" : "下一个") : "提交 / 看答案", pink) { reveal(w) }
                }
                if revealed { BigButton("🔊 听英文", .gray) { Speaker.shared.speak(w.en) } }
            }
        }
        .onAppear { say() }
        .onChange(of: i) { _ in say() }
    }
    func say() { if i < words.count { let z = words[i].zh; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Speaker.shared.speakZh(z) } } }
    func restart(_ ws: [Word]) { words = ws; wrongList = []; right = 0; resetQ(); i = 0; say() }
    func resetQ() { input = ""; revealed = false; showZh = false; result = ""; selfJudge = false }
    func next() { resetQ(); i += 1 }
    func reveal(_ w: Word) {
        if revealed { next(); return }
        revealed = true
        Speaker.shared.speak(w.en)
        if input.trimmingCharacters(in: .whitespaces).isEmpty {
            resColor = .blue; result = "答案：\(w.en)"; selfJudge = true
        } else if norm(input) == norm(w.en) {
            right += 1; store.wrong.remove(w.en); resColor = .green; result = "✓ 正确：\(w.en)"
        } else {
            wrongList.append(w); store.wrong.insert(w.en); resColor = .red; result = "✗ 正确：\(w.en)\n你写的：\(input)"
        }
    }
}

struct PlanView: View {
    @EnvironmentObject var store: Store
    @State private var confirmClear = false
    var body: some View {
        Page(title: "遗忘曲线复习计划") {
            if store.review.isEmpty {
                Text("还没有内容。进入任意单元，点“学完了，加入遗忘曲线复习计划”，或直接在下面加入。").foregroundColor(.secondary)
                ForEach(Data0.units) { u in BigButton("加入 Unit \(u.n) \(u.title)", purple) { store.addToPlan(u) } }
            } else {
                let due = store.dueItems()
                let dw = due.filter { $0.isWord }.count
                Card {
                    Text("今天要复习：单词 \(dw) 个，句子 \(due.count - dw) 句").font(.headline).foregroundColor(purple)
                    Text("记得的会隔 1→2→4→7→15→30 天再出现，忘了的明天重来。").font(.caption).foregroundColor(.secondary)
                }
                if due.isEmpty { Text("今天的复习已完成 👍").font(.headline).foregroundColor(.green) }
                else {
                    NavigationLink { ReviewView(items: due) } label: {
                        Text("▶ 开始今日复习").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(purple).cornerRadius(12)
                    }.buttonStyle(.plain)
                }
                Text("未来 7 天计划").font(.headline).padding(.top, 8)
                ForEach(1...7, id: \.self) { k in
                    let day = todayN() + k
                    let list = store.review.filter { $0.value.d == day }
                    let w = list.keys.filter { $0.hasPrefix("w:") }.count
                    let date = Calendar.current.date(byAdding: .day, value: k, to: Date())!
                    let c = Calendar.current.dateComponents([.month, .day], from: date)
                    Text("\(c.month!)月\(c.day!)日\(k == 1 ? "（明天）" : "")：单词 \(w) · 句子 \(list.count - w)")
                }
                Text("各单元掌握情况").font(.headline).padding(.top, 8)
                ForEach(Data0.units) { u in
                    let ks = store.review.filter { $0.value.u == u.n }
                    if ks.isEmpty { BigButton("加入 Unit \(u.n) \(u.title)", .gray) { store.addToPlan(u) } }
                    else {
                        let done = ks.values.filter { $0.st >= curve.count }.count
                        let avg = ks.values.map { $0.st }.reduce(0, +) * 100 / (ks.count * curve.count)
                        Text("Unit \(u.n)：进度 \(avg)%，已牢记 \(done) / \(ks.count)")
                    }
                }
                BigButton("清空复习计划", .red) { confirmClear = true }.padding(.top, 12)
            }
        }
        .alert("清空全部复习进度？", isPresented: $confirmClear) {
            Button("清空", role: .destructive) { store.review = [:] }
            Button("取消", role: .cancel) {}
        }
    }
}

struct ReviewView: View {
    @EnvironmentObject var store: Store
    let items: [Store.RItem]
    @State private var i = 0
    @State private var ok = 0
    @State private var show = false
    var body: some View {
        Page(title: "今日复习") {
            if i >= items.count {
                Text("今日复习完成！记得 \(ok) / \(items.count)").font(.title2.bold()).foregroundColor(.green).padding(.top, 30)
                Text("忘了的明天会再出现。").foregroundColor(.secondary)
            } else {
                let it = items[i]
                Text("\(i + 1) / \(items.count) · \(it.isWord ? "单词" : "句子") · Unit \(it.unit)").foregroundColor(.secondary)
                Text(it.zh).font(it.isWord ? .largeTitle.bold() : .title2.bold()).foregroundColor(purple)
                Text("先想（或说/写）出英文，再看答案").font(.caption).foregroundColor(.secondary)
                if show { Text(it.en).font(it.isWord ? .largeTitle.bold() : .title2.bold()).foregroundColor(.blue) }
                if !show { BigButton("👀 看答案并发音") { show = true; Speaker.shared.speak(it.en) } }
                else {
                    HStack {
                        BigButton("✓ 记得", .green) { store.grade(it.key, ok: true); ok += 1; show = false; i += 1 }
                        BigButton("✗ 忘了", .red) { store.grade(it.key, ok: false); if it.isWord { store.wrong.insert(it.en) }; show = false; i += 1 }
                    }
                    BigButton("🔊 再听一遍", .gray) { Speaker.shared.speak(it.en) }
                }
            }
        }
    }
}

struct WrongView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let list = Data0.units.flatMap { $0.words }.filter { store.wrong.contains($0.en) }
        return Page(title: "错词本") {
            if list.isEmpty { Text("太棒了，还没有错词。").font(.title3).padding(.top, 20) }
            else {
                NavigationLink { DictationView(words: list.shuffled()) } label: { Text("错词听写").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(orange).cornerRadius(12) }.buttonStyle(.plain)
                NavigationLink { ZhSetupView(words: list, title: "错词中译英听写") } label: { Text("错词中译英听写").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(pink).cornerRadius(12) }.buttonStyle(.plain)
                BigButton("清空错词本", .red) { store.wrong = [] }
                ForEach(list) { w in
                    Card { Text(w.en).font(.headline); Text(w.zh).foregroundColor(.secondary) }
                        .onTapGesture { Speaker.shared.speak(w.en) }
                }
            }
        }
    }
}
