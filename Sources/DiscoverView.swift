import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { BrowserView() } label: {
                        row("safari", "浏览器", "浏览网站，收藏喜爱的内容；网页视频可投车机")
                    }
                }
                Section {
                    NavigationLink { CastReceiverView() } label: {
                        row("arrow.up.forward.app", "从 App 投屏", "哔哩哔哩、抖音、夸克等自带投屏按钮的 App")
                    }
                }
            }
            .navigationTitle("发现")
        }
    }

    private func row(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title).foregroundColor(.green).frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(sub).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}

struct CastReceiverView: View {
    @ObservedObject private var dlna = DLNARenderer.shared
    @State private var showPlayer = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photoItems: [PhotosPickerItem] = []
    @Environment(\.openURL) private var openURL

    private let apps: [(String, String)] = [("哔哩哔哩", "bilibili://"), ("抖音", "snssdk1128://"), ("夸克", "quark://"), ("YouTube", "youtube://")]

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).stroke(Color.gray, lineWidth: 5)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.2)))
                        Text(dlna.friendlyName).foregroundColor(.secondary)
                    }
                    .frame(width: 240, height: 150)
                    Text(dlna.status).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    if let ip = dlna.localIP() { Text("本机地址 \(ip)").font(.caption).foregroundColor(.secondary) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            Section {
                ForEach(apps, id: \.0) { name, scheme in
                    Button { if let u = URL(string: scheme) { openURL(u) } } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.square").foregroundColor(.green)
                            Text(name).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }
            } header: { Text("媒体 App") } footer: {
                Text("在这些 App 里点「投屏/TV」按钮，选择「\(dlna.friendlyName)」。手机需连着 Wi-Fi 或开着个人热点。部分 App 投屏时会限制清晰度，或不允许投某些视频。")
            }
            Section("本地视频") {
                Button { showFiles = true } label: { Label("选择文件", systemImage: "folder") }
                Button { showPhotos = true } label: { Label("从相册选", systemImage: "photo.on.rectangle") }
            }
        }
        .navigationTitle("从 App 投屏")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dlna.onPlay = { showPlayer = true }
            dlna.start()
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 1, matching: .videos)
        .onChange(of: photoItems) { items in
            guard !items.isEmpty else { return }
            PhotoImporter.importItems(items) { _ in
                photoItems = []
                if let item = Library.shared.localItems.last {
                    PlayerModel.shared.play(item, queue: Library.shared.localItems)
                    showPlayer = true
                }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audiovisualContent], allowsMultipleSelection: false) { r in
            if case .success(let urls) = r, let u = urls.first {
                Library.shared.importFile(u)
                if let item = Library.shared.localItems.first(where: { $0.url.lastPathComponent == u.lastPathComponent }) {
                    PlayerModel.shared.play(item, queue: [item])
                    showPlayer = true
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) { PlayerView() }
    }
}
