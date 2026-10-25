import Foundation
import AVFoundation
import Speech

// MARK: - 数据
struct Item: Identifiable, Hashable {
    let id: String
    let lesson: Int
    let lessonTitle: String
    let type: String
    let q: String
    let blanks: [String]
    let alt: [[String]]
    let a: String
    let keys: [String]
    let memory: String
    let diagram: String
    var isFill: Bool { type == "fill" }
    var answerText: String {
        if !isFill { return a }
        var s = q
        for b in blanks { if let r = s.range(of: "____") { s.replaceSubrange(r, with: "【\(b)】") } }
        return s
    }
}
struct LessonData: Identifiable, Hashable { let id: Int; let title: String; let items: [Item] }

enum Bank {
    static let lessons: [LessonData] = {
        guard let url = Bundle.main.url(forResource: "bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ls = obj["lessons"] as? [[String: Any]] else { return [] }
        return ls.map { l in
            let lid = l["id"] as? Int ?? 0
            let title = l["title"] as? String ?? ""
            let arr = l["items"] as? [[String: Any]] ?? []
            let items = arr.enumerated().map { (k, it) -> Item in
                Item(id: "\(lid)-\(k)", lesson: lid, lessonTitle: title, type: it["type"] as? String ?? "qa",
                     q: it["q"] as? String ?? "", blanks: it["blanks"] as? [String] ?? [],
                     alt: it["alt"] as? [[String]] ?? [], a: it["a"] as? String ?? "",
                     keys: it["keys"] as? [String] ?? [], memory: it["memory"] as? String ?? "",
                     diagram: it["diagram"] as? String ?? "")
            }
            return LessonData(id: lid, title: title, items: items)
        }
    }()
    static let all: [Item] = lessons.flatMap { $0.items }
}

// MARK: - 设置与错题（遗忘曲线）
final class Store: ObservableObject {
    static let shared = Store()
    private let d = UserDefaults.standard
    @Published var speed: Double { didSet { d.set(speed, forKey: "speed") } }
    @Published var engine: Int { didSet { d.set(engine, forKey: "engine") } }
    @Published var waitSec: Int { didSet { d.set(waitSec, forKey: "waitSec") } }
    @Published var useMic: Bool { didSet { d.set(useMic, forKey: "useMic") } }
    @Published var review: [String: [String: Int]] { didSet { if let data = try? JSONSerialization.data(withJSONObject: review) { d.set(data, forKey: "review") } } }
    let curve = [1, 2, 4, 7, 15, 30]

    init() {
        speed = d.object(forKey: "speed") as? Double ?? 1.0
        engine = d.integer(forKey: "engine")
        waitSec = d.object(forKey: "waitSec") as? Int ?? 10
        useMic = d.object(forKey: "useMic") as? Bool ?? true
        if let data = d.data(forKey: "review"), let r = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Int]] { review = r } else { review = [:] }
    }
    func today() -> Int { Int((Date().timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT())) / 86400) }
    func markWrong(_ it: Item) {
        var o = review[it.id] ?? [:]
        o["st"] = 0; o["d"] = today() + 1; o["w"] = (o["w"] ?? 0) + 1
        review[it.id] = o
    }
    func markRight(_ it: Item, inReview: Bool) {
        guard var o = review[it.id] else { return }
        if !inReview && (o["d"] ?? 0) > today() { return }
        let st = (o["st"] ?? 0) + 1
        o["st"] = st; o["d"] = today() + (st >= curve.count ? 99999 : curve[st])
        review[it.id] = o
    }
    var wrongItems: [Item] { Bank.all.filter { (review[$0.id]?["st"] ?? 99) < curve.count } }
    var dueItems: [Item] { let t = today(); return Bank.all.filter { if let o = review[$0.id] { return (o["st"] ?? 0) < curve.count && (o["d"] ?? 0) <= t }; return false } }
    var mastered: Int { Bank.all.filter { (review[$0.id]?["st"] ?? 0) >= curve.count }.count }
}

// MARK: - 中文朗读
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    private var player: AVPlayer?
    private var obs: NSKeyValueObservation?
    private var endObs: NSObjectProtocol?
    private var token = 0
    private var ttsDone: (() -> Void)?

    override init() { super.init(); synth.delegate = self }

    func session() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try? s.setActive(true)
    }

    private func clean(_ t: String) -> String {
        var s = t.replacingOccurrences(of: "____", with: "，")
        for c in ["【", "】", "《", "》", "“", "”", "\"", "（", "）", "(", ")"] { s = s.replacingOccurrences(of: c, with: "") }
        return s.replacingOccurrences(of: "；", with: "，").replacingOccurrences(of: "\n", with: "，").trimmingCharacters(in: .whitespaces)
    }
    private func chunks(_ t: String) -> [String] {
        var out: [String] = []; var sb = ""
        for c in t {
            sb.append(c)
            if ("。！？!?".contains(c) && sb.count >= 8) || ("，、：:,".contains(c) && sb.count >= 40) || sb.count >= 70 { out.append(sb); sb = "" }
        }
        if !sb.trimmingCharacters(in: .whitespaces).isEmpty { out.append(sb) }
        return out
    }

    func speak(_ text: String, done: (() -> Void)? = nil) {
        stop(); session()
        token += 1; let my = token
        let parts = chunks(clean(text))
        if parts.isEmpty { DispatchQueue.main.async { done?() }; return }
        if Store.shared.engine == 1 { sys(parts, 0, my, done) } else { online(parts, 0, my, done) }
    }

    private func online(_ parts: [String], _ i: Int, _ my: Int, _ done: (() -> Void)?) {
        guard my == token else { return }
        if i >= parts.count { done?(); return }
        let spd = max(2, min(9, Int(5 * Store.shared.speed)))
        let enc = parts[i].addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? parts[i]
        guard let url = URL(string: "https://fanyi.baidu.com/gettts?lan=zh&text=\(enc)&spd=\(spd)&source=web") else { sys(parts, i, my, done); return }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item); player = p
        obs = item.observe(\.status, options: [.new]) { [weak self] it, _ in
            DispatchQueue.main.async {
                guard let self = self, self.token == my else { return }
                if it.status == .readyToPlay { p.play() } else if it.status == .failed { self.sys(parts, i, my, done) }
            }
        }
        if let e = endObs { NotificationCenter.default.removeObserver(e) }
        endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self = self, self.token == my else { return }
            self.online(parts, i + 1, my, done)
        }
    }

    private func sys(_ parts: [String], _ i: Int, _ my: Int, _ done: (() -> Void)?) {
        guard my == token else { return }
        if i >= parts.count { done?(); return }
        let u = AVSpeechUtterance(string: parts[i])
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        u.rate = Float(AVSpeechUtteranceDefaultSpeechRate) * Float(Store.shared.speed)
        ttsDone = { [weak self] in self?.sys(parts, i + 1, my, done) }
        synth.speak(u)
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        DispatchQueue.main.async { let d = self.ttsDone; self.ttsDone = nil; d?() }
    }

    func stop() {
        token += 1; ttsDone = nil
        player?.pause(); player = nil; obs = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
}

// MARK: - 收音（语音识别 zh-CN）
final class Listener: ObservableObject {
    static let shared = Listener()
    @Published var text = ""
    @Published var state = ""
    private let engine = AVAudioEngine()
    private var req: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let rec = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var session = 0
    private var heard = false
    private var onEnd: ((String, Bool) -> Void)?
    private var onTimeout: (() -> Void)?
    private var silenceWork: DispatchWorkItem?
    private var long = false

    static func ask() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func start(long: Bool, onEnd: @escaping (String, Bool) -> Void, onTimeout: @escaping () -> Void) {
        stop()
        session += 1; let my = session
        self.long = long; self.onEnd = onEnd; self.onTimeout = onTimeout
        text = ""; heard = false
        let wait = Double(Store.shared.waitSec)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self = self, self.session == my, !self.heard else { return }
            self.stop(); onTimeout()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (long ? 90 : 30)) { [weak self] in
            guard let self = self, self.session == my else { return }
            self.finish()
        }
        guard Store.shared.useMic, SFSpeechRecognizer.authorizationStatus() == .authorized, let rec = rec, rec.isAvailable else {
            state = "🗣 请大声说出答案，说完点“我答完了”"; return
        }
        Speaker.shared.session()
        let r = SFSpeechAudioBufferRecognitionRequest(); r.shouldReportPartialResults = true; req = r
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { b, _ in r.append(b) }
        engine.prepare()
        do { try engine.start() } catch { state = "🗣 麦克风不可用，说完点“我答完了”"; return }
        state = "🎤 请说出答案…"
        task = rec.recognitionTask(with: r) { [weak self] res, err in
            DispatchQueue.main.async {
                guard let self = self, self.session == my else { return }
                if let res = res {
                    let t = res.bestTranscription.formattedString
                    if !t.isEmpty { self.heard = true; self.text = t; self.state = "🎤 正在听…"; self.armSilence(my) }
                    if res.isFinal { self.finish() }
                } else if err != nil, self.heard { self.finish() }
            }
        }
    }

    private func armSilence(_ my: Int) {
        silenceWork?.cancel()
        let w = DispatchWorkItem { [weak self] in guard let self = self, self.session == my else { return }; self.finish() }
        silenceWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + (long ? 3.5 : 1.8), execute: w)
    }

    func finish() {
        let t = text; let h = heard || !t.isEmpty
        let cb = onEnd
        stop()
        cb?(t, h)
    }

    func stop() {
        session += 1
        silenceWork?.cancel(); silenceWork = nil
        onEnd = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        req?.endAudio(); req = nil
        task?.cancel(); task = nil
    }
}

// MARK: - 判分
enum Judge {
    static let cn: [Character: Character] = ["零": "0", "〇": "0", "一": "1", "二": "2", "两": "2", "三": "3", "四": "4", "五": "5", "六": "6", "七": "7", "八": "8", "九": "9"]
    static func norm(_ s: String) -> String {
        var t = String(s.filter { !" \t\n，。、！？,.!?；;：:“”\"'《》【】（）()·".contains($0) })
        // 十的处理
        var out = ""; let arr = Array(t)
        for (i, c) in arr.enumerated() {
            if c == "十" {
                let prevNum = i > 0 && cn[arr[i - 1]] != nil
                let nextNum = i + 1 < arr.count && cn[arr[i + 1]] != nil
                if prevNum && nextNum { continue }
                if prevNum { out.append("0"); continue }
                if nextNum { out.append("1"); continue }
                out.append("10"); continue
            }
            out.append(cn[c] ?? c)
        }
        t = out
        return t.lowercased()
    }
    static func hit(_ said: String, _ target: String) -> Bool {
        let s = Array(norm(said)); let t = Array(norm(target))
        if t.isEmpty { return false }
        if String(s).contains(String(t)) { return true }
        if t.count <= 2 { return false }
        var used = Array(repeating: false, count: s.count); var m = 0
        for c in t { if let i = s.indices.first(where: { !used[$0] && s[$0] == c }) { used[i] = true; m += 1 } }
        return Double(m) >= (Double(t.count) * 0.75).rounded(.up)
    }
    static func fill(_ said: String, _ blank: String, _ alts: [String]) -> Bool { hit(said, blank) || alts.contains { hit(said, $0) } }
}
