import SwiftUI
import WebKit

struct Bookmark: Codable, Hashable, Identifiable {
    var id: String { url }
    var title: String
    var url: String
}

final class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()
    @Published var items: [Bookmark] = []
    private let key = "bookmarks"
    static let defaults: [Bookmark] = [
        Bookmark(title: "央视网直播", url: "https://tv.cctv.com/live/"),
        Bookmark(title: "哔哩哔哩", url: "https://m.bilibili.com"),
        Bookmark(title: "YouTube", url: "https://m.youtube.com"),
        Bookmark(title: "百度", url: "https://www.baidu.com")
    ]
    init() {
        if let d = UserDefaults.standard.data(forKey: key), let b = try? JSONDecoder().decode([Bookmark].self, from: d) {
            items = b
        } else {
            items = BookmarkStore.defaults
        }
    }
    func add(_ b: Bookmark) {
        guard !items.contains(where: { $0.url == b.url }) else { return }
        items.insert(b, at: 0); save()
    }
    func remove(_ b: Bookmark) { items.removeAll { $0 == b }; save() }
    func has(_ url: String) -> Bool { items.contains { $0.url == url } }
    private func save() {
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: key) }
    }
}

final class WebModel: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    let webView: WKWebView
    @Published var title = ""
    @Published var urlString = ""
    @Published var videoURLs: [String] = []
    @Published var canGoBack = false
    @Published var progress: Double = 0
    private var obs: [NSKeyValueObservation] = []

    static let sniffJS = """
    (function(){
      if (window.__cpSniff) return; window.__cpSniff = true;
      function post(u){ try{ if(u && /^https?:/.test(u)) window.webkit.messageHandlers.cpVideo.postMessage(u);}catch(e){} }
      function isMedia(u){ return /\\.(m3u8|mp4|m4v|mov|flv)(\\?|$)/i.test(u); }
      var oo = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(m,u){ if(isMedia(String(u))) post(new URL(u, location.href).href); return oo.apply(this, arguments); };
      var of = window.fetch;
      if (of) window.fetch = function(i, o){ var u = (typeof i === 'string') ? i : (i && i.url); if(u && isMedia(u)) post(new URL(u, location.href).href); return of.apply(this, arguments); };
      function scan(){ document.querySelectorAll('video, video source').forEach(function(v){ var s = v.currentSrc || v.src; if(s) post(s); }); }
      document.addEventListener('play', function(e){ if(e.target && e.target.tagName==='VIDEO'){ post(e.target.currentSrc || e.target.src); } }, true);
      setInterval(scan, 2000);
    })();
    """

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.allowsAirPlayForMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: WebModel.sniffJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        cfg.userContentController = ucc
        webView = WKWebView(frame: .zero, configuration: cfg)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        super.init()
        ucc.add(self, name: "cpVideo")
        webView.navigationDelegate = self
        obs.append(webView.observe(\.title) { [weak self] w, _ in DispatchQueue.main.async { self?.title = w.title ?? "" } })
        obs.append(webView.observe(\.url) { [weak self] w, _ in DispatchQueue.main.async {
            self?.urlString = w.url?.absoluteString ?? ""; self?.videoURLs = [] } })
        obs.append(webView.observe(\.canGoBack) { [weak self] w, _ in DispatchQueue.main.async { self?.canGoBack = w.canGoBack } })
        obs.append(webView.observe(\.estimatedProgress) { [weak self] w, _ in DispatchQueue.main.async { self?.progress = w.estimatedProgress } })
    }

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let s = message.body as? String, !s.hasPrefix("blob:") else { return }
        DispatchQueue.main.async {
            if !self.videoURLs.contains(s) { self.videoURLs.append(s) }
        }
    }

    func load(_ input: String) {
        var s = input.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        if !s.contains("://") {
            if s.contains(".") && !s.contains(" ") { s = "https://" + s }
            else { s = "https://www.baidu.com/s?wd=" + (s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s) }
        }
        if let u = URL(string: s) { webView.load(URLRequest(url: u)) }
    }
}

struct WebViewRep: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserView: View {
    @StateObject private var web = WebModel()
    @ObservedObject private var store = BookmarkStore.shared
    @State private var address = ""
    @State private var showPlayer = false
    @State private var showBookmarks = false
    var startURL: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { web.webView.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!web.canGoBack)
                TextField("输入网址或搜索", text: $address, onCommit: { web.load(address) })
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button { web.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                Button {
                    if store.has(web.urlString) {
                        if let b = store.items.first(where: { $0.url == web.urlString }) { store.remove(b) }
                    } else if !web.urlString.isEmpty {
                        store.add(Bookmark(title: web.title.isEmpty ? web.urlString : web.title, url: web.urlString))
                    }
                } label: { Image(systemName: store.has(web.urlString) ? "heart.fill" : "heart") }
                Button { showBookmarks = true } label: { Image(systemName: "book") }
            }
            .font(.title3)
            .padding(8)
            if web.progress < 1 {
                ProgressView(value: web.progress).tint(.green)
            }
            ZStack(alignment: .bottom) {
                WebViewRep(webView: web.webView)
                if let v = web.videoURLs.last {
                    Button {
                        let item = MediaItem(url: URL(string: v)!, title: web.title.isEmpty ? "网页视频" : web.title, isRemote: true, group: nil, logo: nil, userAgent: web.webView.customUserAgent, referer: web.urlString)
                        PlayerModel.shared.play(item, queue: [item])
                        showPlayer = true
                    } label: {
                        Label("检测到视频，用播放器打开（可投车机）", systemImage: "play.rectangle.fill")
                            .font(.headline)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onReceive(web.$urlString) { address = $0 }
        .onAppear { if web.urlString.isEmpty { web.load(startURL ?? "https://tv.cctv.com/live/") } }
        .sheet(isPresented: $showBookmarks) {
            NavigationStack {
                List {
                    ForEach(store.items) { b in
                        Button { web.load(b.url); showBookmarks = false } label: {
                            VStack(alignment: .leading) {
                                Text(b.title).foregroundColor(.primary)
                                Text(b.url).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .onDelete { idx in idx.map { store.items[$0] }.forEach(store.remove) }
                }
                .navigationTitle("收藏")
            }
        }
        .fullScreenCover(isPresented: $showPlayer) { PlayerView() }
        .navigationBarTitleDisplayMode(.inline)
    }
}
