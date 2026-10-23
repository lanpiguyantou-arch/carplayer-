import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject var library: Library
    @State private var showImporter = false
    @State private var showAddURL = false
    @State private var showSubscribe = false
    @State private var showPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var nameText = ""
    @State private var urlText = ""
    @State private var groupText = ""
    @State private var subText = ""
    @State private var showPlayer = false
    @State private var tab = 0
    @State private var showClearConfirm = false
    static let recommended: [(String, String)] = [
        ("vbskycn/iptv（每6小时更新）", "https://live.zbds.top/tv/iptv4.m3u"),
        ("suxuang/myIPTV IPv4", "https://gh-proxy.org/raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u"),
        ("zhi35/iptv（每日更新）", "https://live.zhi35.com/iptv.m3u")
    ]
    @State private var selectedGroup: String?
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var currentGroupName: String? {
        let names = library.remoteGroups.map { $0.name }
        if let s = selectedGroup, names.contains(s) { return s }
        return names.first
    }

    @ViewBuilder private var liveView: some View {
        if library.remoteItems.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tv").font(.system(size: 50)).foregroundColor(.secondary)
                Text("点右上角 + →「订阅频道列表」\n粘贴 m3u / txt 直播源地址").multilineTextAlignment(.center).foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(library.remoteGroups, id: \.name) { g in
                        let on = g.name == currentGroupName
                        Text(g.name)
                            .font(.headline)
                            .padding(.horizontal, 18).padding(.vertical, 9)
                            .background(on ? Color.green : Color(white: 0.17))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .onTapGesture { selectedGroup = g.name }
                            .contextMenu {
                                Button(role: .destructive) { library.deleteGroup(g.name) } label: { Label("删除这个分组", systemImage: "trash") }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            ScrollView {
                let items = uniqueByTitle(library.remoteGroups.first { $0.name == currentGroupName }?.items ?? [])
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(items) { item in
                        Button { open(item, queue: items) } label: { card(item) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { library.delete(item) } label: { Label("删除频道", systemImage: "trash") }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }

    private var localView: some View {
        List {
            if library.localItems.isEmpty {
                Text("点右上角 + 从相册或文件导入；同名 .srt 字幕会自动显示。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            ForEach(library.localItems) { item in
                row(item, queue: library.localItems)
            }
            .onDelete { offsets in
                let items = offsets.map { library.localItems[$0] }
                items.forEach { library.delete($0) }
            }
        }
    }

    private func card(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.13))
                if let logo = item.logo, let u = URL(string: logo) {
                    AsyncImage(url: u) { img in img.resizable().scaledToFit().padding(18) }
                        placeholder: { Image(systemName: "tv").font(.system(size: 44)).foregroundColor(.white) }
                } else {
                    Image(systemName: "tv").font(.system(size: 44)).foregroundColor(.white)
                }
            }
            .aspectRatio(16.0/9.0, contentMode: .fit)
            Text(item.title).font(.headline).foregroundColor(.white).lineLimit(1)
        }
    }

    private func uniqueByTitle(_ items: [MediaItem]) -> [MediaItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.title).inserted }
    }

    private func open(_ item: MediaItem, queue: [MediaItem]) {
        library.resolve(item) { resolved in
            guard let resolved = resolved else { return }
            PlayerModel.shared.play(resolved, queue: queue)
            showPlayer = true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("直播 / 电视台").tag(0)
                    Text("本地视频").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 6)
                if importing {
                    HStack { ProgressView(); Text("正在从相册导入…") }.padding(4)
                }
                if let msg = library.lastMessage {
                    Text(msg).font(.footnote).foregroundColor(.secondary).padding(4)
                }
                if tab == 0 { liveView } else { localView }
            }
            .navigationTitle("车载播放器")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showPhotos = true } label: { Label("从相册导入视频", systemImage: "photo.on.rectangle") }
                        Button { showImporter = true } label: { Label("从文件导入", systemImage: "folder") }
                        Button { showSubscribe = true } label: { Label("订阅频道列表 (m3u/txt)", systemImage: "antenna.radiowaves.left.and.right") }
                        Button { showAddURL = true } label: { Label("添加单个链接", systemImage: "link") }
                        Menu {
                            ForEach(LibraryView.recommended, id: \.1) { name, url in
                                Button(name) { if let u = URL(string: url) { library.subscribe(u); tab = 0 } }
                            }
                        } label: { Label("推荐直播源 (GitHub)", systemImage: "star") }
                        Divider()
                        Button(role: .destructive) { showClearConfirm = true } label: { Label("清空所有网络源", systemImage: "trash") }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .refreshable { library.reload() }
            .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 20, matching: .videos)
            .onChange(of: photoItems) { items in
                guard !items.isEmpty else { return }
                importing = true
                PhotoImporter.importItems(items) { n in
                    importing = false
                    library.lastMessage = "从相册导入了 \(n) 个视频"; tab = 1
                    photoItems = []
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audiovisualContent, .plainText, .item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    urls.forEach { library.importFile($0) }
                }
            }
            .alert("添加单个链接", isPresented: $showAddURL) {
                TextField("名称，如 CCTV-1", text: $nameText)
                TextField("地址 http://...", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                TextField("分组/电视台，如 央视", text: $groupText)
                Button("添加") {
                    library.addRemote(name: nameText, url: urlText, group: groupText)
                    nameText = ""; urlText = ""; groupText = ""
                }
                Button("取消", role: .cancel) { nameText = ""; urlText = ""; groupText = "" }
            }
            .alert("订阅频道列表", isPresented: $showSubscribe) {
                TextField("m3u / txt 地址", text: $subText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                Button("导入") {
                    if let u = URL(string: subText.trimmingCharacters(in: .whitespaces)), u.scheme != nil {
                        library.subscribe(u); tab = 0
                    } else {
                        library.lastMessage = "地址格式不对"
                    }
                    subText = ""
                }
                Button("取消", role: .cancel) { subText = "" }
            } message: {
                Text("频道会按 group-title / #genre# 自动分到各电视台")
            }
            .confirmationDialog("清空所有网络源？本地视频不受影响", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { library.clearRemote() }
                Button("取消", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showPlayer) {
                PlayerView()
            }
            .onAppear { library.reload() }
        }
    }

    private func row(_ item: MediaItem, queue: [MediaItem]) -> some View {
        Button {
            open(item, queue: queue)
        } label: {
            HStack(spacing: 12) {
                if let logo = item.logo, let u = URL(string: logo) {
                    AsyncImage(url: u) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "tv").foregroundColor(.accentColor)
                    }
                    .frame(width: 40, height: 28)
                } else {
                    Image(systemName: item.isRemote ? "tv" : "film")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 40)
                }
                Text(item.title)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(.vertical, 6)
        }
    }
}
