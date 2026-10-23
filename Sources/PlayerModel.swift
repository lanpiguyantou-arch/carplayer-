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

    func play(_ item: MediaItem, queue: [MediaItem]) {
        self.queue = queue
        current = item
        currentTime = 0
        duration = 0
        let playerItem = AVPlayerItem(url: item.url)
        player.replaceCurrentItem(with: playerItem)
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
        guard let c = current, let i = queue.firstIndex(of: c), i + 1 < queue.count else {
            isPlaying = false
            updateNowPlaying()
            return
        }
        play(queue[i + 1], queue: queue)
    }

    func previous() {
        if currentTime > 5 { seek(to: 0); return }
        guard let c = current, let i = queue.firstIndex(of: c), i > 0 else { seek(to: 0); return }
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
