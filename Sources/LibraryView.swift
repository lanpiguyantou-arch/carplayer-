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
    @State private var collapsed: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                if importing {
                    HStack { ProgressView(); Text("正在从相册导入…") }
                }
                if let msg = library.lastMessage {
                    Text(msg).font(.footnote).foregroundColor(.secondary)
                }
                Section("本地视频") {
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
                if library.remoteItems.isEmpty {
                    Section("网络 / 电视台") {
                        Text("点 + →「订阅频道列表」，粘贴 m3u 或 txt 直播源地址，会按电视台自动分组。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                ForEach(library.remoteGroups, id: \.name) { group in
                    Section {
                        if !collapsed.contains(group.name) {
                            ForEach(group.items) { item in
                                row(item, queue: group.items)
                                    .swipeActions {
                                        Button(role: .destructive) { library.delete(item) } label: { Label("删除", systemImage: "trash") }
                                    }
                            }
                        }
                    } header: {
                        HStack {
                            Button {
                                if collapsed.contains(group.name) { collapsed.remove(group.name) } else { collapsed.insert(group.name) }
                            } label: {
                                HStack {
                                    Image(systemName: collapsed.contains(group.name) ? "chevron.right" : "chevron.down")
                                    Text("\(group.name)（\(group.items.count)）")
                                }
                            }
                            Spacer()
                            Menu {
                                Button(role: .destructive) { library.deleteGroup(group.name) } label: { Label("删除整个分组", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("车载播放器")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showPhotos = true } label: { Label("从相册导入视频", systemImage: "photo.on.rectangle") }
                        Button { showImporter = true } label: { Label("从文件导入", systemImage: "folder") }
                        Button { showSubscribe = true } label: { Label("订阅频道列表 (m3u/txt)", systemImage: "antenna.radiowaves.left.and.right") }
                        Button { showAddURL = true } label: { Label("添加单个链接", systemImage: "link") }
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
                    library.lastMessage = "从相册导入了 \(n) 个视频"
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
                        library.subscribe(u)
                    } else {
                        library.lastMessage = "地址格式不对"
                    }
                    subText = ""
                }
                Button("取消", role: .cancel) { subText = "" }
            } message: {
                Text("频道会按 group-title / #genre# 自动分到各电视台")
            }
            .fullScreenCover(isPresented: $showPlayer) {
                PlayerView()
            }
            .onAppear { library.reload() }
        }
    }

    private func row(_ item: MediaItem, queue: [MediaItem]) -> some View {
        Button {
            PlayerModel.shared.play(item, queue: queue)
            showPlayer = true
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
