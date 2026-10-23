import AVFoundation
import Foundation

final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    private var player: AVPlayer?
    private var statusObs: NSKeyValueObservation?
    private var endObs: NSObjectProtocol?
    private let synth = AVSpeechSynthesizer()
    var onDone: (() -> Void)?
    private var token = 0

    override init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func enc(_ t: String) -> String { t.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? t }
    private func youdao(_ t: String) -> URL { URL(string: "https://dict.youdao.com/dictvoice?audio=\(enc(t))&type=\(Store.shared.accent)")! }
    private func baidu(_ t: String, lan: String? = nil, spd: Int = 5) -> URL {
        URL(string: "https://fanyi.baidu.com/gettts?lan=\(lan ?? (Store.shared.accent == 1 ? "uk" : "en"))&text=\(enc(t))&spd=\(spd)&source=web")!
    }

    func speak(_ text: String, slow: Bool = false) {
        stop()
        let rate = Float(Store.shared.speed) * (slow ? 0.6 : 1)
        if Store.shared.engine == 1 { tts(text, rate: rate, lang: Store.shared.accent == 1 ? "en-GB" : "en-US"); return }
        let urls = text.trimmingCharacters(in: .whitespaces).contains(" ") ? [baidu(text), youdao(text)] : [youdao(text), baidu(text)]
        play(urls, 0, rate: rate) { [weak self] in self?.tts(text, rate: rate, lang: Store.shared.accent == 1 ? "en-GB" : "en-US") }
    }

    func speakZh(_ text: String) {
        stop()
        let t = text.replacingOccurrences(of: "[（(][^）)]*[）)]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "；", with: "，").replacingOccurrences(of: ";", with: "，")
        play([baidu(t, lan: "zh", spd: 4)], 0, rate: 1) { [weak self] in self?.tts(t, rate: 1, lang: "zh-CN") }
    }

    private func play(_ urls: [URL], _ i: Int, rate: Float, fallback: @escaping () -> Void) {
        guard i < urls.count else { fallback(); return }
        token += 1; let my = token
        let item = AVPlayerItem(url: urls[i])
        item.audioTimePitchAlgorithm = .timeDomain
        let p = AVPlayer(playerItem: item)
        player = p
        statusObs = item.observe(\.status, options: [.new]) { [weak self] it, _ in
            DispatchQueue.main.async {
                guard let self = self, self.token == my else { return }
                if it.status == .readyToPlay { p.playImmediately(atRate: max(0.3, min(2, rate))) }
                else if it.status == .failed { self.play(urls, i + 1, rate: rate, fallback: fallback) }
            }
        }
        endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self = self, self.token == my else { return }
            self.onDone?()
        }
    }

    private func tts(_ text: String, rate: Float, lang: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: lang)
        u.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * rate))
        synth.speak(u)
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { DispatchQueue.main.async { self.onDone?() } }

    func stop() {
        token += 1
        player?.pause(); player = nil
        statusObs = nil
        if let e = endObs { NotificationCenter.default.removeObserver(e); endObs = nil }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
}
