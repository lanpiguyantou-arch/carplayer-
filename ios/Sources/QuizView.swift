import SwiftUI

enum Phase { case reading, listening, judged, timeout, revealed, memory, itemDone, summary }

struct QuizView: View {
    let spec: QuizSpec
    @EnvironmentObject var store: Store
    @ObservedObject var lis = Listener.shared
    @Environment(\.dismiss) var dismiss
    @State private var idx = 0
    @State private var k = 0
    @State private var filled: [String?] = []
    @State private var phase: Phase = .reading
    @State private var ok = true
    @State private var said = ""
    @State private var heard = false
    @State private var lastRight: Bool? = nil
    @State private var hits: [Bool] = []
    @State private var right = 0
    @State private var wrongList: [Item] = []
    @State private var started = false

    var item: Item? { idx < spec.items.count ? spec.items[idx] : nil }
    var segs: [String] { item.map { $0.q.components(separatedBy: "____") } ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if phase == .summary || item == nil { summaryView } else if let it = item {
                    Text("第 \(idx + 1) / \(spec.items.count) 题 · 第\(it.lesson)课 \(it.lessonTitle) · \(it.isFill ? "填空题" : "问答题")").font(.footnote).foregroundColor(.gray)
                    Card { Text(it.isFill ? fillText(it) : it.q).font(.title2.bold()) }
                    statusView(it)
                    actions(it)
                }
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(spec.title)
        .onAppear { if !started { started = true; startItem() } }
        .onDisappear { Listener.shared.stop(); Speaker.shared.stop() }
    }

    func fillText(_ it: Item) -> String {
        var s = ""
        for j in segs.indices {
            s += segs[j]
            if j < segs.count - 1 {
                if j < filled.count { s += "【\(filled[j] ?? "？")】" } else if j == k { s += " ___🎤___ " } else { s += " ______ " }
            }
        }
        return s
    }

    @ViewBuilder func statusView(_ it: Item) -> some View {
        switch phase {
        case .reading: Text("🔊 正在读题…").font(.headline).foregroundColor(.blue)
        case .listening:
            Text(lis.state.isEmpty ? "🎤 请说出答案" : lis.state).font(.headline).foregroundColor(.blue)
            if !lis.text.isEmpty { Text("听到：\(lis.text)").foregroundColor(.secondary) }
        case .judged:
            if !said.isEmpty { Text("你说的：\(said)").foregroundColor(.secondary) }
            if let r = lastRight {
                if it.isFill { Text(r ? "✅ 答对了！" : "🤔 好像不太对，再想想？").font(.headline).foregroundColor(r ? .green : orange) }
                else {
                    let n = hits.filter { $0 }.count
                    Text(r ? "✅ 答得不错！说到了 \(n)/\(it.keys.count) 个要点" : "🤔 说到了 \(n)/\(it.keys.count) 个要点，还差一点").font(.headline).foregroundColor(r ? .green : orange)
                    Text("要点：" + it.keys.enumerated().map { hits[$0.offset] ? "✓\($0.element)" : "○？" }.joined(separator: "   ")).foregroundColor(.secondary)
                }
            } else { Text(heard ? "👂 听到回答了！对不对？" : "回答完了吗？").font(.headline).foregroundColor(.blue) }
        case .timeout: Text("⏰ \(store.waitSec) 秒没听到回答。要不要看正确答案？").font(.headline).foregroundColor(orange)
        case .revealed:
            if it.isFill {
                Text("正确答案：\(it.blanks[min(k, it.blanks.count - 1)])").font(.title3.bold()).foregroundColor(.green)
                if !it.memory.isEmpty { Text("🧠 记忆小窍门：\(it.memory)").foregroundColor(purple) }
            } else {
                Text("参考答案").font(.headline).foregroundColor(.green)
                Card(color: Color.green.opacity(0.12)) { Text(it.a).font(.body) }
                if !it.keys.isEmpty { Text("必须说到的要点：" + it.keys.joined(separator: "、")).font(.headline).foregroundColor(brand) }
            }
        case .memory:
            Card(color: Color.purple.opacity(0.10)) {
                if !it.keys.isEmpty {
                    Text("第一步 · 抓关键词").font(.subheadline.bold()).foregroundColor(purple)
                    Text(it.keys.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")).font(.title3)
                }
                if !it.memory.isEmpty {
                    Text("第二步 · 口诀/联想").font(.subheadline.bold()).foregroundColor(purple).padding(.top, 6)
                    Text(it.memory).font(.title3.bold()).foregroundColor(purple)
                }
                if !it.diagram.isEmpty {
                    Text("第三步 · 看图理解").font(.subheadline.bold()).foregroundColor(purple).padding(.top, 6)
                    Text(it.diagram).font(.system(.body, design: .monospaced)).padding(8).background(Color.white).cornerRadius(8)
                }
                Text("最后 · 闭上眼睛，按关键词顺序把答案说一遍；明天再复习一次。").font(.footnote).foregroundColor(.secondary).padding(.top, 6)
            }
        case .itemDone: Text(ok ? "🎉 这题全对！" : "📕 这题已记进错题本").font(.headline).foregroundColor(ok ? .green : .red)
        case .summary: EmptyView()
        }
    }

    @ViewBuilder func actions(_ it: Item) -> some View {
        switch phase {
        case .reading: BigButton("⏭ 跳过朗读，直接回答", .gray) { Speaker.shared.stop(); listen() }
        case .listening:
            HStack { BigButton("✓ 我答完了", .green) { Listener.shared.finish() }; BigButton("🔁 再读一遍", .blue) { read() } }
        case .judged:
            if let r = lastRight {
                if it.isFill {
                    if r { BigButton("继续 ▶", .green) { advance() } }
                    else {
                        HStack { BigButton("🎤 再说一次", .blue) { listen() }; BigButton("👀 查看答案", orange) { reveal() } }
                        BigButton("其实我答对了（识别错了）", .gray) { filled.append(it.blanks[k]); advance() }
                    }
                } else {
                    HStack { BigButton("继续 ▶", .green) { phase = .itemDone }; BigButton("🎤 再答一次", .blue) { listen() } }
                    BigButton("👀 查看参考答案", orange) { reveal() }
                    BigButton("🧠 怎么记住这题", purple) { memory() }
                    if !r { BigButton("👨‍👩‍👧 家长改判：其实答对了", .gray) { ok = true; lastRight = true; phase = .itemDone } }
                }
            } else {
                HStack {
                    BigButton(it.isFill ? "✓ 答对了，继续" : "✓ 答全了，继续", .green) { if it.isFill { filled.append(it.blanks[k]); advance() } else { phase = .itemDone } }
                    BigButton(it.isFill ? "✗ 答错了" : "✗ 没答全", .red) { reveal() }
                }
                BigButton("👀 查看答案", orange) { reveal() }
            }
        case .timeout:
            HStack { BigButton("👀 查看答案", orange) { reveal() }; BigButton("🎤 再想想", .blue) { listen() } }
            BigButton("其实已经答完了", .gray) { answered("", true) }
        case .revealed:
            HStack {
                BigButton(it.isFill ? "记住了，继续 ▶" : "看完了，继续 ▶", .green) { if it.isFill { advance() } else { phase = .itemDone } }
                BigButton("🔊 再听一遍", .blue) { Speaker.shared.speak(it.answerText) }
            }
            if !it.isFill { BigButton("🧠 教我怎么记", purple) { memory() } }
        case .memory:
            HStack { BigButton("🎤 闭眼复述一遍", .blue) { listen() }; BigButton("下一题 ▶", brand) { nextItem() } }
            BigButton("🔊 再读一遍口诀", purple) { Speaker.shared.speak(it.memory) }
        case .itemDone:
            HStack { BigButton("下一题 ▶", brand) { nextItem() }; BigButton(it.isFill ? "🔊 完整读一遍" : "👀 对一对答案", .blue) { if it.isFill { Speaker.shared.speak(it.answerText) } else { let keep = ok; reveal(); ok = keep } } }
            if !it.isFill { BigButton("🧠 怎么记住这题", purple) { memory() } }
        case .summary: EmptyView()
        }
    }

    var summaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Card {
                Text("完成啦！🎉").font(.largeTitle.bold()).foregroundColor(.green)
                Text("答对 \(right) 题，没答好 \(wrongList.count) 题").font(.title3)
                if !wrongList.isEmpty { Text("没答好的已放进错题本，明天开始按遗忘曲线复习。").font(.footnote).foregroundColor(.gray) }
            }
            if !wrongList.isEmpty {
                NavigationLink(value: Route.quiz(QuizSpec(items: wrongList, title: "再练一遍", review: false))) { Pill("🔁 马上再练没答好的（\(wrongList.count)）", .red) }
                ForEach(wrongList) { w in Text("• " + (w.isFill ? w.answerText : w.q + "\n   答：" + w.a)) }
            }
        }
    }

    // MARK: - 流程
    func startItem() {
        guard let it = item else { phase = .summary; Speaker.shared.speak(wrongList.isEmpty ? "太棒了，全部答对！" : "完成啦，答对\(right)题。"); return }
        k = 0; filled = []; ok = true; said = ""; lastRight = nil
        if it.isFill { readSeg(0) } else { read() }
    }
    func read() {
        guard let it = item else { return }
        if it.isFill { readSeg(k); return }
        Listener.shared.stop(); phase = .reading
        Speaker.shared.speak("问答题。" + it.q) { listen() }
    }
    func readSeg(_ j: Int) {
        Listener.shared.stop(); phase = .reading
        let s = segs
        guard j < s.count else { return }
        Speaker.shared.speak(j == 0 ? "填空题。" + s[0] : s[j]) {
            if let it = item, k < it.blanks.count { listen() } else { finishFill() }
        }
    }
    func listen() {
        guard let it = item else { return }
        Speaker.shared.stop()
        phase = .listening; lastRight = nil; said = ""
        Listener.shared.start(long: !it.isFill, onEnd: { t, h in answered(t, h) }, onTimeout: { phase = .timeout; Speaker.shared.speak("没听到回答，要不要看正确答案？") })
    }
    func answered(_ t: String, _ h: Bool) {
        guard let it = item else { return }
        said = t; heard = h
        if !t.isEmpty {
            if it.isFill {
                let r = Judge.fill(t, it.blanks[k], k < it.alt.count ? it.alt[k] : [])
                lastRight = r
                if r { Speaker.shared.speak("答对了") }
                phase = .judged
            } else if !it.keys.isEmpty {
                hits = it.keys.indices.map { Judge.key(t, it, $0) }
                let n = hits.filter { $0 }.count
                let r = n * 10 >= it.keys.count * 6
                lastRight = r; if !r { ok = false }
                Speaker.shared.speak(r ? "答得不错！" : "还差一点哦")
                phase = .judged
            } else { lastRight = nil; phase = .judged }
        } else { lastRight = nil; phase = .judged }
    }
    func reveal() {
        guard let it = item else { return }
        Listener.shared.stop(); ok = false
        phase = .revealed
        if it.isFill { Speaker.shared.speak("正确答案是：" + it.blanks[k]) } else { Speaker.shared.speak(it.a) }
    }
    func memory() {
        guard let it = item else { return }
        Listener.shared.stop(); phase = .memory
        Speaker.shared.speak((it.keys.isEmpty ? "" : "先记关键词：" + it.keys.joined(separator: "，") + "。") + it.memory)
    }
    func advance() {
        guard let it = item else { return }
        Listener.shared.stop()
        if filled.count <= k { filled.append(it.blanks[k]) }
        k += 1
        if k < it.blanks.count { readSeg(k) }
        else {
            let tail = segs.last ?? ""
            if !tail.trimmingCharacters(in: .whitespaces).isEmpty { phase = .reading; Speaker.shared.speak(tail) { finishFill() } } else { finishFill() }
        }
    }
    func finishFill() { phase = .itemDone }
    func nextItem() {
        guard let it = item else { return }
        if ok { right += 1; store.markRight(it, inReview: spec.review) } else { wrongList.append(it); store.markWrong(it) }
        idx += 1
        startItem()
    }
}
