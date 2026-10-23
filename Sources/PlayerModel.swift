import Foundation
import AVFoundation
import MediaPlayer

final class PlayerModel: ObservableObject {
    static let shared = PlayerModel()
    static let rates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    let player = AVPlayer()
    @Published var current: MediaItem?
    @Published var isPlaying = false
    @Published var subtitle = ""
    @Published var rate: Float = 1.0
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var statusText: String?
    var isLive: Bool { current?.isRemote == true && !(duration.isFinite && duration > 0) }
    private var statusObs: NSKeyValueObservation?

    private var cues: [SubtitleCue] = []
    private var queue: [MediaItem] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init() {
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            self?.tick(t.seconds)
        }
        setupRemoteCommands()
    }

    @Published var sourceIndex = 0
    @Published var sourceCount = 1
    private var sources: [MediaItem] = []
    private var timeoutWork: DispatchWorkItem?

    func play(_ item: MediaItem, queue: [MediaItem]) {
        sources = Library.shared.sources(for: item)
        sourceCount = sources.count
        sourceIndex = 0
        start(sources.first ?? item, queue: queue)
    }

    /// Manually or automatically try the next 线路 of the same channel.
    func nextSource(auto: Bool = false) {
        guard sourceCount > 1 else {
            if auto { statusText = "这个频道连不上（源失效或被限制地区），换个频道试试" }
            return
        }
        if auto && sourceIndex + 1 >= sourceCount {
            statusText = "\(sourceCount) 条线路都连不上，换个频道试试"
            return
        }
        sourceIndex = (sourceIndex + 1) % sourceCount
        start(sources[sourceIndex], queue: queue, keepSources: true)
    }

    private func start(_ item: MediaItem, queue: [MediaItem], keepSources: Bool = false) {
        self.queue = queue
        current = item
        currentTime = 0
        duration = 0
        var headers: [String: String] = [:]
        if let ua = item.userAgent, !ua.isEmpty { headers["User-Agent"] = ua }
        if let ref = item.referer, !ref.isEmpty { headers["Referer"] = ref }
        let asset = AVURLAsset(url: item.url, options: headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        timeoutWork?.cancel()
        if item.isRemote {
            let work = DispatchWorkItem { [weak self, weak playerItem] in
                guard let self = self, let p = playerItem, self.player.currentItem === p, p.status != .readyToPlay else { return }
                self.nextSource(auto: true)
            }
            timeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)
        }
        player.replaceCurrentItem(with: playerItem)
        statusText = item.isRemote ? (sourceCount > 1 ? "正在连接 线路\(sourceIndex + 1)/\(sourceCount)…" : "正在连接…") : nil
        statusObs = playerItem.observe(\.status, options: [.new]) { [weak self] it, _ in
            DispatchQueue.main.async {
                switch it.status {
                case .readyToPlay: self?.statusText = nil; self?.timeoutWork?.cancel()
                case .failed:
                    self?.timeoutWork?.cancel()
                    self?.nextSource(auto: true)
                default: break
                }
            }
        }
        loadSubtitles(for: item)
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.next()
        }
        player.playImmediately(atRate: rate)
        isPlaying = true
        updateNowPlaying()
    }

    func toggle() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.playImmediately(atRate: rate)
            isPlaying = true
        }
        updateNowPlaying()
    }

    func stop() {
        player.pause()
        isPlaying = false
        statusText = nil
        timeoutWork?.cancel()
        updateNowPlaying()
    }

    func seek(by delta: Double) {
        seek(to: player.currentTime().seconds + delta)
    }

    func seek(to t: Double) {
        let target = max(0, duration > 0 ? min(t, duration) : t)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        updateNowPlaying()
    }

    func setRate(_ r: Float) {
        rate = r
        if isPlaying { player.rate = r }
        updateNowPlaying()
    }

    func next() {
        guard let c = current, let i = queue.firstIndex(where: { $0.title == c.title && $0.group == c.group }), i + 1 < queue.count else {
            isPlaying = false
            updateNowPlaying()
            return
        }
        play(queue[i + 1], queue: queue)
    }

    func previous() {
        if currentTime > 5 { seek(to: 0); return }
        guard let c = current, let i = queue.firstIndex(where: { $0.title == c.title && $0.group == c.group }), i > 0 else { seek(to: 0); return }
        play(queue[i - 1], queue: queue)
    }

    private func loadSubtitles(for item: MediaItem) {
        cues = []
        subtitle = ""
        guard !item.isRemote else { return }
        cues = SRTParser.load(item.url.deletingPathExtension().appendingPathExtension("srt"))
    }

    private func tick(_ t: Double) {
        if t.isFinite { currentTime = t }
        if let d = player.currentItem?.duration.seconds, d.isFinite, d != duration { duration = d }
        guard !cues.isEmpty else { return }
        let text = cues.first(where: { t >= $0.start && t <= $0.end })?.text ?? ""
        if text != subtitle { subtitle = text }
    }

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying { self.toggle() }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying { self.toggle() }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggle()
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = current?.title ?? ""
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(rate) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
