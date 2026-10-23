import SwiftUI
import WebKit

struct SVGView: UIViewRepresentable {
    let svg: String
    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView()
        w.isOpaque = false; w.backgroundColor = .clear; w.scrollView.isScrollEnabled = false
        return w
    }
    func updateUIView(_ w: WKWebView, context: Context) {
        let html = """
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>
        html,body{margin:0;background:transparent;color:#222;display:flex;align-items:center;justify-content:center;height:100%}
        @media (prefers-color-scheme: dark){html,body{color:#eee}}
        svg{max-width:100%;max-height:100%;height:auto}</style></head><body>\(svg)</body></html>
        """
        w.loadHTMLString(html, baseURL: nil)
    }
}

/// One question with input + check. Calls onResult(correct, answerText) once checked.
struct QuestionCard: View {
    let question: Question
    var showTopic = true
    var onResult: (Bool, String) -> Void
    @State private var input = ""
    @State private var choice: String?
    @State private var checked: Verdict?
    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showTopic, let t = KG.shared.byId[question.t] {
                Text("\(t.v) · \(t.n)").font(.caption).foregroundColor(.secondary)
            }
            Text(question.p).font(.title3).fixedSize(horizontal: false, vertical: true)
            if let f = question.f { SVGView(svg: f).frame(height: 180) }
            if question.ty == "choice", let cs = question.c {
                ForEach(cs, id: \.self) { c in
                    Button { if checked == nil { choice = c.k } } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Text(c.k).bold().frame(width: 28, height: 28).background(Circle().fill(bg(c.k))).foregroundColor(.white)
                            if let f = c.f { SVGView(svg: f).frame(height: 90).allowsHitTesting(false) }
                            if question.hc != true || c.f == nil { Text(c.x).foregroundColor(.primary).multilineTextAlignment(.leading) }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).stroke(choice == c.k ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else if question.ty == "self" {
                if !revealed {
                    Button("想好了，看答案") { revealed = true }.buttonStyle(.borderedProminent)
                }
            } else {
                TextField(question.uo == true ? "多个答案用逗号隔开" : "输入答案", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .disabled(checked != nil)
                    .onSubmit(check)
            }

            if question.ty == "self" && revealed && checked == nil {
                answerBox
                HStack {
                    Button("我做对了") { finish(.correct, "自评对") }.buttonStyle(.borderedProminent).tint(.green)
                    Button("我做错了") { finish(.wrong, "自评错") }.buttonStyle(.bordered).tint(.red)
                }
            } else if checked == .manual {
                answerBox
                Text("这题需要你自己对照：").font(.subheadline)
                HStack {
                    Button("和答案一致") { finish(.correct, input) }.buttonStyle(.borderedProminent).tint(.green)
                    Button("不一致") { finish(.wrong, input) }.buttonStyle(.bordered).tint(.red)
                }
            } else if let v = checked {
                Label(v == .correct ? "答对了" : "答错了", systemImage: v == .correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.headline).foregroundColor(v == .correct ? .green : .red)
                answerBox
            } else if question.ty != "self" {
                HStack {
                    Button("提交", action: check).buttonStyle(.borderedProminent)
                        .disabled(question.ty == "choice" ? choice == nil : input.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("不会") { finish(.wrong, "不会") }.buttonStyle(.bordered)
                }
            }
        }
        .id(question.id)
    }

    private var answerBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("答案：\(question.a)").bold()
            if !question.ex.isEmpty { Text(question.ex).foregroundColor(.secondary) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))
    }

    private func bg(_ k: String) -> Color {
        if let v = checked, v != .manual {
            if k == question.a { return .green }
            if k == choice { return .red }
        }
        return choice == k ? .accentColor : .gray
    }

    private func check() {
        focused = false
        let text = question.ty == "choice" ? (choice ?? "") : input
        let v = Judge.judge(question, text)
        if v == .manual { checked = .manual; return }
        finish(v, text)
    }

    private func finish(_ v: Verdict, _ text: String) {
        checked = v
        onResult(v == .correct, text)
    }
}

struct PracticeView: View {
    @EnvironmentObject var store: Store
    let title: String
    let questions: [Question]
    @State private var i = 0
    @State private var done = false
    @State private var right = 0
    @State private var answered = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if questions.isEmpty {
                    Text("这里还没有题目。").foregroundColor(.secondary)
                } else if i < questions.count {
                    ProgressView(value: Double(i), total: Double(questions.count))
                    Text("第 \(i + 1) / \(questions.count) 题").font(.caption).foregroundColor(.secondary)
                    QuestionCard(question: questions[i]) { ok, text in
                        store.record(questions[i], ok: ok, answer: text)
                        if ok { right += 1 }
                        updateMastery(questions[i].t, ok)
                        answered = true
                    }
                    if answered {
                        Button(i + 1 < questions.count ? "下一题" : "完成") { i += 1; answered = false }
                            .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "rosette").font(.system(size: 56)).foregroundColor(.orange)
                        Text("完成！答对 \(right) / \(questions.count)").font(.title2.bold())
                        Button("再练一遍") { i = 0; right = 0; answered = false }.buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Simple rule: last 2 answers on the topic in this session decide mastery.
    @State private var history: [String: [Bool]] = [:]
    private func updateMastery(_ topic: String, _ ok: Bool) {
        history[topic, default: []].append(ok)
        let h = history[topic]!.suffix(2)
        if h.count == 2 { store.mastery[topic] = h.allSatisfy { $0 } ? .mastered : (h.contains(true) ? .shaky : .weak) }
        else if h.first == false { store.mastery[topic] = store.mastery[topic] == .mastered ? .shaky : .weak }
        else if store.mastery[topic] == nil { store.mastery[topic] = .shaky }
    }
}
