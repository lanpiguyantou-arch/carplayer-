import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject var library: Library
    @State private var showImporter = false
    @State private var showAddURL = false
    @State private var urlText = ""
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            List {
                Section("本地视频") {
                    if library.localItems.isEmpty {
                        Text("点右上角 + 导入视频；同名 .srt 字幕一起导入会自动显示。也可以在「文件」App →「我的 iPhone」→「车载播放器」里放文件。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    ForEach(library.localItems) { item in
                        row(item)
                    }
                    .onDelete { offsets in
                        let items = offsets.map { library.localItems[$0] }
                        items.forEach { library.delete($0) }
                    }
                }
                Section("网络链接") {
                    if library.remoteItems.isEmpty {
                        Text("支持 mp4、m3u8 等视频直链")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    ForEach(library.remoteItems) { item in
                        row(item)
                    }
                    .onDelete { offsets in
                        let items = offsets.map { library.remoteItems[$0] }
                        items.forEach { library.delete($0) }
                    }
                }
            }
            .navigationTitle("车载播放器")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showImporter = true } label: { Label("导入文件", systemImage: "folder") }
                        Button { showAddURL = true } label: { Label("添加网络链接", systemImage: "link") }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .refreshable { library.reload() }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audiovisualContent, .item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    urls.forEach { library.importFile($0) }
                }
            }
            .alert("添加网络链接", isPresented: $showAddURL) {
                TextField("http://...", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                Button("添加") {
                    library.addRemote(urlText)
                    urlText = ""
                }
                Button("取消", role: .cancel) { urlText = "" }
            } message: {
                Text("粘贴视频地址")
            }
            .fullScreenCover(isPresented: $showPlayer) {
                PlayerView()
            }
            .onAppear { library.reload() }
        }
    }

    private func row(_ item: MediaItem) -> some View {
        Button {
            PlayerModel.shared.play(item, queue: item.isRemote ? library.remoteItems : library.localItems)
            showPlayer = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isRemote ? "globe" : "film")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 32)
                Text(item.title)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(.vertical, 8)
        }
    }
}
