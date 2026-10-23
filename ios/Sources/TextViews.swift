import SwiftUI
import PhotosUI
import Vision
import UIKit

struct MyTextsView: View {
    @EnvironmentObject var store: Store
    @State private var del: MyText? = nil
    var body: some View {
        Page(title: "我的课文") {
            NavigationLink { AddTextView(unit: 0, preTitle: "") } label: {
                Text("＋ 添加一篇课文").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(teal).cornerRadius(12)
            }.buttonStyle(.plain)
            if store.myTexts.isEmpty { Text("还没有课文。可以拍课本，也可以把英文打进来或粘贴进来。").foregroundColor(.secondary).padding(.top, 10) }
            ForEach(store.myTexts.reversed()) { t in
                NavigationLink { PointReadView(title: "我的课文", sub: t.title, textID: t.id, fixed: []) } label: {
                    Card { Text(t.title).font(.headline).foregroundColor(.primary); Text("\(t.lines.count) 句 · 长按删除").font(.caption).foregroundColor(.secondary) }
                }.buttonStyle(.plain)
                .contextMenu { Button("删除", role: .destructive) { store.myTexts.removeAll { $0.id == t.id } } }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(self) }
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let p: CameraPicker
        init(_ p: CameraPicker) { self.p = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { p.onImage(img) }
            p.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { p.dismiss() }
    }
}

func ocrEnglish(_ img: UIImage, done: @escaping ([String]) -> Void) {
    guard let cg = img.cgImage else { done([]); return }
    let orient: CGImagePropertyOrientation = {
        switch img.imageOrientation {
        case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right
        case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }()
    let req = VNRecognizeTextRequest { r, _ in
        let obs = (r.results as? [VNRecognizedTextObservation]) ?? []
        let raw = obs.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }
            .filter { l in
                let latin = l.unicodeScalars.filter { CharacterSet.letters.contains($0) && $0.isASCII }.count
                let all = l.filter { !$0.isWhitespace }.count
                return latin >= 2 && latin * 2 >= all
            }
        var out: [String] = []
        for l in raw {
            let speaker = l.range(of: "^[A-Z][A-Za-z ]{1,15}:", options: .regularExpression) != nil
            if out.isEmpty || speaker || out.last!.range(of: "[.!?\"”]$", options: .regularExpression) != nil { out.append(l) }
            else { out[out.count - 1] += " " + l }
        }
        DispatchQueue.main.async { done(out) }
    }
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["en-US"]
    req.usesLanguageCorrection = true
    DispatchQueue.global(qos: .userInitiated).async {
        try? VNImageRequestHandler(cgImage: cg, orientation: orient).perform([req])
    }
}

struct AddTextView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let unit: Int
    @State var title: String
    @State private var en = ""
    @State private var zh = ""
    @State private var showCam = false
    @State private var photo: PhotosPickerItem? = nil
    @State private var msg = ""
    init(unit: Int, preTitle: String) { self.unit = unit; _title = State(initialValue: preTitle) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("标题，如 Unit 1 Part B", text: $title).padding(10).background(Color(.systemBackground)).cornerRadius(10)
                Text("英文课文（一行一句最准确，也可整段粘贴自动分句）").font(.subheadline).foregroundColor(.secondary)
                TextEditor(text: $en).frame(minHeight: 180).padding(4).background(Color(.systemBackground)).cornerRadius(10)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                HStack {
                    Button { if UIImagePickerController.isSourceTypeAvailable(.camera) { showCam = true } else { msg = "相机不可用，请从相册选" } } label: {
                        Text("📷 拍照识别").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(teal).cornerRadius(12)
                    }.buttonStyle(.plain)
                    PhotosPicker(selection: $photo, matching: .images) {
                        Text("🖼 从相册选").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(teal).cornerRadius(12)
                    }
                }
                Text(msg.isEmpty ? "可以分几次拍（一页一张），识别结果会接在后面，记得对照课本改错字。" : msg).font(.caption).foregroundColor(msg.isEmpty ? .secondary : teal)
                Text("中文翻译（可不填，不填会自动在线翻译）").font(.subheadline).foregroundColor(.secondary)
                TextEditor(text: $zh).frame(minHeight: 100).padding(4).background(Color(.systemBackground)).cornerRadius(10)
                BigButton("保存", teal) { save() }
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("添加课文").navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCam) { CameraPicker { img in recognize(img) }.ignoresSafeArea() }
        .onChange(of: photo) { item in
            guard let item = item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Foundation.Data.self), let img = UIImage(data: d) { recognize(img) }
                else { msg = "读取图片失败" }
                photo = nil
            }
        }
    }
    func recognize(_ img: UIImage) {
        msg = "正在识别课文…"
        ocrEnglish(img) { out in
            if out.isEmpty { msg = "没识别到英文，拍清楚一点再试"; return }
            let old = en.trimmingCharacters(in: .whitespacesAndNewlines)
            en = (old.isEmpty ? "" : old + "\n") + out.joined(separator: "\n")
            msg = "识别到 \(out.count) 行，请对照课本改一下错字再保存"
        }
    }
    func save() {
        let es = splitEn(en)
        guard !es.isEmpty else { msg = "先输入或拍照识别英文课文"; return }
        let zs = splitZh(zh)
        let lines = es.enumerated().map { Line(en: $0.element, zh: zs.count == es.count ? zs[$0.offset] : "") }
        let t = title.trimmingCharacters(in: .whitespaces).isEmpty ? "课文 \(store.myTexts.count + 1)" : title
        store.myTexts.append(MyText(title: t, unit: unit, lines: lines))
        dismiss()
    }
}
