import Foundation
import Network
import Darwin

/// Minimal DLNA / UPnP MediaRenderer named "CarTV (iPhone)". Apps such as 哔哩哔哩 / 抖音 / 夸克 / YouTube push a video URL here,
/// and we play it with AVPlayer (which can then be sent to the CarPlay screen via AirPlay).
final class DLNARenderer: ObservableObject {
    static let shared = DLNARenderer()
    @Published var running = false
    @Published var status = "未启动"
    @Published var lastTitle: String?
    var onPlay: (() -> Void)?

    let friendlyName = "CarTV (iPhone)"
    private let uuid: String = {
        if let s = UserDefaults.standard.string(forKey: "dlnaUUID") { return s }
        let s = UUID().uuidString.lowercased(); UserDefaults.standard.set(s, forKey: "dlnaUUID"); return s
    }()
    private let port: UInt16 = 49_888
    private var listener: NWListener?
    private var ssdpSocket: Int32 = -1
    private var ssdpThread: Thread?
    private var notifyTimer: Timer?
    private var currentURI = ""

    // MARK: start/stop
    func start() {
        guard !running else { return }
        do {
            let l = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            l.newConnectionHandler = { [weak self] c in self?.handle(c) }
            l.start(queue: .global())
            listener = l
        } catch {
            status = "HTTP 服务启动失败：\(error.localizedDescription)"; return
        }
        running = true
        startSSDP()
        notifyTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.sendNotify() }
        sendNotify()
        status = localIP() == nil ? "已启动，但没连 Wi-Fi/热点，其他 App 可能找不到" : "等待 App 投屏…"
    }

    func stop() {
        listener?.cancel(); listener = nil
        notifyTimer?.invalidate(); notifyTimer = nil
        if ssdpSocket >= 0 { close(ssdpSocket); ssdpSocket = -1 }
        running = false
        status = "未启动"
    }

    // MARK: SSDP
    private func startSSDP() {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { status = "SSDP 失败"; return }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(1900).bigEndian
        addr.sin_addr.s_addr = 0
        let b = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        if b != 0 { DispatchQueue.main.async { self.status = "等待 App 投屏…（1900 端口被占用）" } }
        var mreq = ip_mreq()
        mreq.imr_multiaddr.s_addr = inet_addr("239.255.255.250")
        mreq.imr_interface.s_addr = 0
        if setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size)) != 0 {
            DispatchQueue.main.async { self.status = "等待 App 投屏…（系统限制了组播，可能搜不到，见说明）" }
        }
        ssdpSocket = fd
        let t = Thread { [weak self] in self?.ssdpLoop(fd) }
        t.start(); ssdpThread = t
    }

    private func ssdpLoop(_ fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        while ssdpSocket == fd {
            var from = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { p in
                p.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, &buf, buf.count, 0, $0, &len) }
            }
            if n <= 0 { break }
            let msg = String(decoding: buf[0..<n], as: UTF8.self)
            guard msg.hasPrefix("M-SEARCH") else { continue }
            let st = header("ST", in: msg) ?? "ssdp:all"
            let targets = ["ssdp:all", "upnp:rootdevice", "urn:schemas-upnp-org:device:MediaRenderer:1",
                           "urn:schemas-upnp-org:service:AVTransport:1", "uuid:\(uuid)"]
            guard targets.contains(st) || st.contains("MediaRenderer") || st.contains("AVTransport") else { continue }
            let replyST = st == "ssdp:all" ? "urn:schemas-upnp-org:device:MediaRenderer:1" : st
            guard let ip = localIP() else { continue }
            let resp = "HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\nEXT:\r\nLOCATION: http://\(ip):\(port)/description.xml\r\nSERVER: iOS/26 UPnP/1.0 CarTV/1.0\r\nST: \(replyST)\r\nUSN: uuid:\(uuid)::\(replyST)\r\n\r\n"
            var to = from
            _ = resp.withCString { s in
                withUnsafePointer(to: &to) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, s, strlen(s), 0, $0, len) } }
            }
        }
    }

    private func sendNotify() {
        guard let ip = localIP() else { return }
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(1900).bigEndian
        addr.sin_addr.s_addr = inet_addr("239.255.255.250")
        for nt in ["upnp:rootdevice", "urn:schemas-upnp-org:device:MediaRenderer:1", "urn:schemas-upnp-org:service:AVTransport:1"] {
            let m = "NOTIFY * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nCACHE-CONTROL: max-age=1800\r\nLOCATION: http://\(ip):\(port)/description.xml\r\nNT: \(nt)\r\nNTS: ssdp:alive\r\nSERVER: iOS/26 UPnP/1.0 CarTV/1.0\r\nUSN: uuid:\(uuid)::\(nt)\r\n\r\n"
            _ = m.withCString { s in
                withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, s, strlen(s), 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
            }
        }
    }

    private func header(_ name: String, in msg: String) -> String? {
        for line in msg.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    func localIP() -> String? {
        var result: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let a = p.pointee
            guard a.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: a.ifa_name)
            guard name == "en0" || name.hasPrefix("bridge") || name == "en2" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(a.ifa_addr, socklen_t(a.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: host)
            if name == "en0" { return ip }
            result = result ?? ip
        }
        return result
    }

    // MARK: HTTP
    private func handle(_ c: NWConnection) {
        c.start(queue: .global())
        var buffer = Data()
        func receive() {
            c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, err in
                guard let self = self else { return }
                if let d = data { buffer.append(d) }
                if let req = self.completeRequest(buffer) {
                    let resp = self.respond(req)
                    c.send(content: resp, completion: .contentProcessed { _ in c.cancel() })
                } else if done || err != nil {
                    c.cancel()
                } else {
                    receive()
                }
            }
        }
        receive()
    }

    private struct Request { let method: String; let path: String; let headers: [String: String]; let body: String }

    private func completeRequest(_ data: Data) -> Request? {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: data[..<sep.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        let first = lines.removeFirst().split(separator: " ")
        guard first.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for l in lines {
            let p = l.split(separator: ":", maxSplits: 1)
            if p.count == 2 { headers[p[0].lowercased().trimmingCharacters(in: .whitespaces)] = p[1].trimmingCharacters(in: .whitespaces) }
        }
        let len = Int(headers["content-length"] ?? "0") ?? 0
        let bodyData = data[sep.upperBound...]
        if bodyData.count < len { return nil }
        return Request(method: String(first[0]), path: String(first[1]), headers: headers, body: String(decoding: bodyData.prefix(len), as: UTF8.self))
    }

    private func http(_ body: String, type: String = "text/xml; charset=\"utf-8\"", status: String = "200 OK", extra: String = "") -> Data {
        let b = Data(body.utf8)
        let h = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(b.count)\r\nServer: iOS/26 UPnP/1.0 CarTV/1.0\r\n\(extra)Connection: close\r\n\r\n"
        return Data(h.utf8) + b
    }

    private func respond(_ r: Request) -> Data {
        switch (r.method, r.path) {
        case ("GET", "/description.xml"): return http(description)
        case ("GET", "/AVTransport.xml"): return http(DLNAXML.avTransportSCPD)
        case ("GET", "/RenderingControl.xml"): return http(DLNAXML.renderingSCPD)
        case ("GET", "/ConnectionManager.xml"): return http(DLNAXML.connectionSCPD)
        case ("SUBSCRIBE", _): return http("", extra: "SID: uuid:\(UUID().uuidString)\r\nTIMEOUT: Second-1800\r\n")
        case ("UNSUBSCRIBE", _): return http("")
        case ("POST", _):
            let action = (r.headers["soapaction"] ?? "").replacingOccurrences(of: "\"", with: "").components(separatedBy: "#").last ?? ""
            let service = r.path.contains("AVTransport") ? "AVTransport" : r.path.contains("Rendering") ? "RenderingControl" : "ConnectionManager"
            return http(soap(action: action, service: service, body: r.body))
        default: return http("", status: "404 Not Found")
        }
    }

    private func tag(_ name: String, in xml: String) -> String? {
        guard let s = xml.range(of: "<\(name)>") ?? xml.range(of: "<\(name) "), let e = xml.range(of: "</\(name)>", range: s.upperBound..<xml.endIndex) else { return nil }
        var start = s.upperBound
        if xml[s].hasSuffix(" "), let gt = xml[start...].firstIndex(of: ">") { start = xml.index(after: gt) }
        return String(xml[start..<e.lowerBound])
    }

    private func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&apos;", with: "'")
         .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    private func hms(_ t: Double) -> String {
        guard t.isFinite, t > 0 else { return "00:00:00" }
        let i = Int(t); return String(format: "%02d:%02d:%02d", i / 3600, (i % 3600) / 60, i % 60)
    }

    private func seconds(_ s: String) -> Double {
        let p = s.split(separator: ":").compactMap { Double($0) }
        return p.reduce(0) { $0 * 60 + $1 }
    }

    private func soap(action: String, service: String, body: String) -> String {
        let model = PlayerModel.shared
        var out = ""
        let sync: (() -> Void) -> Void = { f in if Thread.isMainThread { f() } else { DispatchQueue.main.sync(execute: f) } }
        switch action {
        case "SetAVTransportURI", "SetNextAVTransportURI":
            let uri = unescape(tag("CurrentURI", in: body) ?? tag("NextURI", in: body) ?? "")
            let meta = unescape(tag("CurrentURIMetaData", in: body) ?? "")
            let title = unescape(tag("dc:title", in: meta) ?? "") 
            currentURI = uri
            if action == "SetAVTransportURI", let u = URL(string: uri) {
                sync {
                    let item = MediaItem(url: u, title: title.isEmpty ? "投屏视频" : title, isRemote: true, group: "投屏", logo: nil)
                    model.play(item, queue: [item])
                    self.lastTitle = item.title
                    self.status = "正在播放：\(item.title)"
                    self.onPlay?()
                }
            }
        case "Play": sync { if !model.isPlaying { model.toggle() } }
        case "Pause": sync { if model.isPlaying { model.toggle() } }
        case "Stop": sync { model.stop(); self.status = "等待 App 投屏…" }
        case "Seek":
            let target = tag("Target", in: body) ?? "0"
            sync { model.seek(to: self.seconds(target)) }
        case "GetTransportInfo":
            var state = "STOPPED"
            sync { state = model.isPlaying ? "PLAYING" : (model.current == nil ? "NO_MEDIA_PRESENT" : "PAUSED_PLAYBACK") }
            out = "<CurrentTransportState>\(state)</CurrentTransportState><CurrentTransportStatus>OK</CurrentTransportStatus><CurrentSpeed>1</CurrentSpeed>"
        case "GetPositionInfo":
            var d = 0.0, t = 0.0
            sync { d = model.duration; t = model.currentTime }
            out = "<Track>1</Track><TrackDuration>\(hms(d))</TrackDuration><TrackMetaData></TrackMetaData><TrackURI>\(esc(currentURI))</TrackURI><RelTime>\(hms(t))</RelTime><AbsTime>\(hms(t))</AbsTime><RelCount>2147483647</RelCount><AbsCount>2147483647</AbsCount>"
        case "GetMediaInfo":
            var d = 0.0
            sync { d = model.duration }
            out = "<NrTracks>1</NrTracks><MediaDuration>\(hms(d))</MediaDuration><CurrentURI>\(esc(currentURI))</CurrentURI><CurrentURIMetaData></CurrentURIMetaData><NextURI></NextURI><NextURIMetaData></NextURIMetaData><PlayMedium>NETWORK</PlayMedium><RecordMedium>NOT_IMPLEMENTED</RecordMedium><WriteStatus>NOT_IMPLEMENTED</WriteStatus>"
        case "GetTransportSettings": out = "<PlayMode>NORMAL</PlayMode><RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>"
        case "GetCurrentTransportActions": out = "<Actions>Play,Pause,Stop,Seek</Actions>"
        case "GetDeviceCapabilities": out = "<PlayMedia>NETWORK</PlayMedia><RecMedia>NOT_IMPLEMENTED</RecMedia><RecQualityModes>NOT_IMPLEMENTED</RecQualityModes>"
        case "GetVolume": out = "<CurrentVolume>\(Int(model.player.volume * 100))</CurrentVolume>"
        case "SetVolume":
            let v = Float(tag("DesiredVolume", in: body) ?? "100") ?? 100
            sync { model.player.volume = max(0, min(1, v / 100)) }
        case "GetMute": out = "<CurrentMute>\(model.player.isMuted ? 1 : 0)</CurrentMute>"
        case "SetMute": let m = tag("DesiredMute", in: body) ?? "0"; sync { model.player.isMuted = (m == "1" || m == "true") }
        case "GetProtocolInfo": out = "<Source></Source><Sink>http-get:*:video/mp4:*,http-get:*:video/*:*,http-get:*:application/vnd.apple.mpegurl:*,http-get:*:application/x-mpegURL:*,http-get:*:audio/*:*,http-get:*:*:*</Sink>"
        case "GetCurrentConnectionIDs": out = "<ConnectionIDs>0</ConnectionIDs>"
        case "GetCurrentConnectionInfo": out = "<RcsID>0</RcsID><AVTransportID>0</AVTransportID><ProtocolInfo></ProtocolInfo><PeerConnectionManager></PeerConnectionManager><PeerConnectionID>-1</PeerConnectionID><Direction>Input</Direction><Status>OK</Status>"
        default: break
        }
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:\(action)Response xmlns:u=\"urn:schemas-upnp-org:service:\(service):1\">\(out)</u:\(action)Response></s:Body></s:Envelope>"
    }

    private var description: String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:dlna="urn:schemas-dlna-org:device-1-0">
        <specVersion><major>1</major><minor>0</minor></specVersion>
        <device>
        <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
        <friendlyName>\(friendlyName)</friendlyName>
        <manufacturer>CarPlayer</manufacturer>
        <modelName>CarTV</modelName>
        <modelNumber>1</modelNumber>
        <UDN>uuid:\(uuid)</UDN>
        <dlna:X_DLNADOC>DMR-1.50</dlna:X_DLNADOC>
        <serviceList>
        <service><serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType><serviceId>urn:upnp-org:serviceId:AVTransport</serviceId><SCPDURL>/AVTransport.xml</SCPDURL><controlURL>/AVTransport/control</controlURL><eventSubURL>/AVTransport/event</eventSubURL></service>
        <service><serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType><serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId><SCPDURL>/RenderingControl.xml</SCPDURL><controlURL>/RenderingControl/control</controlURL><eventSubURL>/RenderingControl/event</eventSubURL></service>
        <service><serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType><serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId><SCPDURL>/ConnectionManager.xml</SCPDURL><controlURL>/ConnectionManager/control</controlURL><eventSubURL>/ConnectionManager/event</eventSubURL></service>
        </serviceList>
        </device>
        </root>
        """
    }
}

enum DLNAXML {
    static func scpd(_ actions: [(String, [(String, String, String)])], _ vars: [(String, String)]) -> String {
        var s = "<?xml version=\"1.0\"?><scpd xmlns=\"urn:schemas-upnp-org:service-1-0\"><specVersion><major>1</major><minor>0</minor></specVersion><actionList>"
        for (name, args) in actions {
            s += "<action><name>\(name)</name><argumentList>"
            for (a, dir, v) in args { s += "<argument><name>\(a)</name><direction>\(dir)</direction><relatedStateVariable>\(v)</relatedStateVariable></argument>" }
            s += "</argumentList></action>"
        }
        s += "</actionList><serviceStateTable>"
        for (v, t) in vars { s += "<stateVariable sendEvents=\"no\"><name>\(v)</name><dataType>\(t)</dataType></stateVariable>" }
        return s + "</serviceStateTable></scpd>"
    }
    static let iid = ("InstanceID", "in", "A_ARG_TYPE_InstanceID")
    static let avTransportSCPD = scpd([
        ("SetAVTransportURI", [iid, ("CurrentURI", "in", "AVTransportURI"), ("CurrentURIMetaData", "in", "AVTransportURIMetaData")]),
        ("Play", [iid, ("Speed", "in", "TransportPlaySpeed")]),
        ("Pause", [iid]), ("Stop", [iid]),
        ("Seek", [iid, ("Unit", "in", "A_ARG_TYPE_SeekMode"), ("Target", "in", "A_ARG_TYPE_SeekTarget")]),
        ("GetTransportInfo", [iid, ("CurrentTransportState", "out", "TransportState"), ("CurrentTransportStatus", "out", "TransportStatus"), ("CurrentSpeed", "out", "TransportPlaySpeed")]),
        ("GetPositionInfo", [iid, ("Track", "out", "CurrentTrack"), ("TrackDuration", "out", "CurrentTrackDuration"), ("TrackMetaData", "out", "CurrentTrackMetaData"), ("TrackURI", "out", "CurrentTrackURI"), ("RelTime", "out", "RelativeTimePosition"), ("AbsTime", "out", "AbsoluteTimePosition"), ("RelCount", "out", "RelativeCounterPosition"), ("AbsCount", "out", "AbsoluteCounterPosition")]),
        ("GetMediaInfo", [iid, ("NrTracks", "out", "NumberOfTracks"), ("MediaDuration", "out", "CurrentMediaDuration"), ("CurrentURI", "out", "AVTransportURI")]),
        ("GetTransportSettings", [iid, ("PlayMode", "out", "CurrentPlayMode")]),
        ("GetCurrentTransportActions", [iid, ("Actions", "out", "CurrentTransportActions")])
    ], [("A_ARG_TYPE_InstanceID", "ui4"), ("AVTransportURI", "string"), ("AVTransportURIMetaData", "string"), ("TransportPlaySpeed", "string"),
        ("A_ARG_TYPE_SeekMode", "string"), ("A_ARG_TYPE_SeekTarget", "string"), ("TransportState", "string"), ("TransportStatus", "string"),
        ("CurrentTrack", "ui4"), ("CurrentTrackDuration", "string"), ("CurrentTrackMetaData", "string"), ("CurrentTrackURI", "string"),
        ("RelativeTimePosition", "string"), ("AbsoluteTimePosition", "string"), ("RelativeCounterPosition", "i4"), ("AbsoluteCounterPosition", "i4"),
        ("NumberOfTracks", "ui4"), ("CurrentMediaDuration", "string"), ("CurrentPlayMode", "string"), ("CurrentTransportActions", "string")])
    static let renderingSCPD = scpd([
        ("GetVolume", [iid, ("Channel", "in", "A_ARG_TYPE_Channel"), ("CurrentVolume", "out", "Volume")]),
        ("SetVolume", [iid, ("Channel", "in", "A_ARG_TYPE_Channel"), ("DesiredVolume", "in", "Volume")]),
        ("GetMute", [iid, ("Channel", "in", "A_ARG_TYPE_Channel"), ("CurrentMute", "out", "Mute")]),
        ("SetMute", [iid, ("Channel", "in", "A_ARG_TYPE_Channel"), ("DesiredMute", "in", "Mute")])
    ], [("A_ARG_TYPE_InstanceID", "ui4"), ("A_ARG_TYPE_Channel", "string"), ("Volume", "ui2"), ("Mute", "boolean")])
    static let connectionSCPD = scpd([
        ("GetProtocolInfo", [("Source", "out", "SourceProtocolInfo"), ("Sink", "out", "SinkProtocolInfo")]),
        ("GetCurrentConnectionIDs", [("ConnectionIDs", "out", "CurrentConnectionIDs")])
    ], [("SourceProtocolInfo", "string"), ("SinkProtocolInfo", "string"), ("CurrentConnectionIDs", "string")])
}
