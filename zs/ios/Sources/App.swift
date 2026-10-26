import SwiftUI
import WebKit
import UserNotifications

@main
struct YibiaoApp: App {
    var body: some Scene { WindowGroup { WebContainer().ignoresSafeArea() } }
}

final class Handler: NSObject, WKScriptMessageHandler {
    weak var web: WKWebView?
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        if m.name == "remind", let s = m.body as? String { schedule(s); return }
        if m.name == "share", let d = m.body as? [String: Any], let name = d["name"] as? String, let data = d["data"] as? String {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? data.data(using: .utf8)?.write(to: url)
            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController {
                vc.popoverPresentationController?.sourceView = root.view
                vc.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 1, height: 1)
                root.present(vc, animated: true)
            }
        }
    }
    func schedule(_ json: String) {
        guard let d = json.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let dates = o["dates"] as? [String] else { return }
        let warn = (o["warn"] as? Int) ?? 30
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            guard ok else { return }
            center.removeAllPendingNotificationRequests()
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
            var counts: [String: Int] = [:]
            for s in dates { counts[s, default: 0] += 1 }
            let cal = Calendar.current
            let now = Date()
            var n = 0
            for key in counts.keys.sorted() {
                guard let due = f.date(from: key), n < 60 else { continue }
                let c = counts[key]!
                for (offset, text) in [(-warn, "\(c) 台仪表将于 \(key) 校验到期（还有\(warn)天）"), (-7, "\(c) 台仪表 7 天后（\(key)）校验到期"), (0, "\(c) 台仪表今天（\(key)）校验到期")] {
                    guard var day = cal.date(byAdding: .day, value: offset, to: due) else { continue }
                    day = cal.date(bySettingHour: 8, minute: 30, second: 0, of: day) ?? day
                    if day <= now || n >= 60 { continue }
                    let ct = UNMutableNotificationContent(); ct.title = "仪表校验到期提醒"; ct.body = text; ct.sound = .default
                    let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: day)
                    center.add(UNNotificationRequest(identifier: "due-\(key)-\(offset)", content: ct, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                    n += 1
                }
            }
        }
    }
}

struct WebContainer: UIViewRepresentable {
    let handler = Handler()
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(handler, name: "remind")
        cfg.userContentController.add(handler, name: "share")
        let w = WKWebView(frame: .zero, configuration: cfg)
        handler.web = w
        w.scrollView.contentInsetAdjustmentBehavior = .never
        w.isOpaque = false
        w.backgroundColor = UIColor(red: 0.93, green: 0.945, blue: 0.96, alpha: 1)
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www") {
            w.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return w
    }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
