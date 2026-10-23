import UIKit
import CarPlay
import Combine
import AVFoundation

/// Video surface shown on the car screen (only available when signed with the CarPlay navigation entitlement).
final class CarVideoViewController: UIViewController {
    private let surface = PlayerUIView()
    private let subtitleLabel = UILabel()
    private let titleLabel = UILabel()
    private var bag = Set<AnyCancellable>()

    override func loadView() {
        view = surface
        surface.backgroundColor = .black
        surface.playerLayer.player = PlayerModel.shared.player
        surface.playerLayer.videoGravity = .resizeAspect

        subtitleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        titleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            subtitleLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: guide.widthAnchor, multiplier: 0.9),
            titleLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: guide.centerYAnchor)
        ])

        let model = PlayerModel.shared
        model.$subtitle.receive(on: RunLoop.main).sink { [weak self] t in
            self?.subtitleLabel.text = t.isEmpty ? nil : " \(t) "
            self?.subtitleLabel.isHidden = t.isEmpty
        }.store(in: &bag)
        model.$current.receive(on: RunLoop.main).sink { [weak self] item in
            self?.titleLabel.text = item == nil ? "点左上角「片库」选择视频" : nil
        }.store(in: &bag)
    }
}

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var carWindow: CPWindow?
    private var videoMode = false

    // Audio-app mode (carplay-audio entitlement): list + Now Playing, sound only.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        videoMode = false
        interfaceController.setRootTemplate(makeList(), animated: true, completion: nil)
    }

    // Navigation-app mode (carplay-maps entitlement): we get a window and can draw the video on the car screen.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController,
                                  to window: CPWindow) {
        self.interfaceController = interfaceController
        self.carWindow = window
        videoMode = true
        window.rootViewController = CarVideoViewController()

        let map = CPMapTemplate()
        map.automaticallyHidesNavigationBar = false
        map.leadingNavigationBarButtons = [
            CPBarButton(title: "片库") { [weak self] _ in self?.showList() }
        ]
        map.trailingNavigationBarButtons = [
            CPBarButton(title: "播放/暂停") { _ in PlayerModel.shared.toggle() }
        ]
        map.mapButtons = [
            mapButton("gobackward.10") { PlayerModel.shared.seek(by: -10) },
            mapButton("goforward.30") { PlayerModel.shared.seek(by: 30) },
            mapButton("backward.end.fill") { PlayerModel.shared.previous() },
            mapButton("forward.end.fill") { PlayerModel.shared.next() }
        ]
        interfaceController.setRootTemplate(map, animated: true, completion: nil)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController,
                                  from window: CPWindow) {
        carWindow?.rootViewController = nil
        carWindow = nil
        self.interfaceController = nil
    }

    private func mapButton(_ symbol: String, action: @escaping () -> Void) -> CPMapButton {
        let b = CPMapButton { _ in action() }
        b.image = UIImage(systemName: symbol)
        return b
    }

    private func showList() {
        interfaceController?.pushTemplate(makeList(), animated: true, completion: nil)
    }

    private func makeList() -> CPListTemplate {
        let library = Library.shared
        library.reload()
        var sections: [CPListSection] = []
        let limit = CPListTemplate.maximumItemCount
        if !library.localItems.isEmpty {
            sections.append(CPListSection(items: Array(library.localItems.prefix(limit)).map { listItem($0, queue: library.localItems) },
                                          header: "本地视频", sectionIndexTitle: nil))
        }
        for group in library.remoteGroups {
            sections.append(CPListSection(items: Array(group.items.prefix(limit)).map { listItem($0, queue: group.items) },
                                          header: group.name, sectionIndexTitle: nil))
        }
        if sections.isEmpty {
            sections = [CPListSection(items: [CPListItem(text: "还没有视频", detailText: "请先在手机上导入")])]
        }
        return CPListTemplate(title: "片库", sections: Array(sections.prefix(CPListTemplate.maximumSectionCount)))
    }

    private func listItem(_ media: MediaItem, queue: [MediaItem]) -> CPListItem {
        let item = CPListItem(text: media.title, detailText: media.isRemote ? (media.group ?? "网络") : "本地")
        item.handler = { [weak self] _, completion in
            PlayerModel.shared.play(media, queue: queue)
            guard let self = self, let ic = self.interfaceController else { completion(); return }
            if self.videoMode {
                ic.popToRootTemplate(animated: true, completion: nil)
            } else {
                ic.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return item
    }
}
