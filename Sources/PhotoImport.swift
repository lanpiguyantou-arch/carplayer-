import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = Library.shared.uniqueDestination(for: received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}

enum PhotoImporter {
    static func importItems(_ items: [PhotosPickerItem], done: @escaping (Int) -> Void) {
        let group = DispatchGroup()
        var count = 0
        let lock = NSLock()
        for item in items {
            group.enter()
            item.loadTransferable(type: PickedMovie.self) { result in
                if case .success(let movie) = result, movie != nil {
                    lock.lock(); count += 1; lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            Library.shared.reload()
            done(count)
        }
    }
}
