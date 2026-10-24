import SwiftUI
import WebKit
import AVFoundation

@main
struct YuwenApp: App {
    var body: some Scene { WindowGroup { WebContainer().ignoresSafeArea() } }
}

final class SpeechHandler: NSObject, WKScriptMessageHandler {
    let synth = AVSpeechSynthesizer()
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        if m.name == "stop" { synth.stopSpeaking(at: .immediate); return }
        guard let t = m.body as? String else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: t)
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        u.rate = 0.42
        synth.speak(u)
    }
}

struct WebContainer: UIViewRepresentable {
    let handler = SpeechHandler()
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(handler, name: "speak")
        cfg.userContentController.add(handler, name: "stop")
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.scrollView.contentInsetAdjustmentBehavior = .never
        w.isOpaque = false
        w.backgroundColor = UIColor(red: 0.965, green: 0.949, blue: 0.918, alpha: 1)
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www") {
            w.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return w
    }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
