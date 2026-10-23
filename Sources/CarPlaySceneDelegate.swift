import UIKit
import CarPlay

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let library = Library.shared
        library.reload()
        let all = library.all
        let items: [CPListItem] = all.map { media in
            let item = CPListItem(text: media.title, detailText: media.isRemote ? "网络" : "本地")
            item.handler = { _, completion in
                PlayerModel.shared.play(media, queue: all)
                interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            return item
        }
        let list = CPListTemplate(title: "车载播放器", sections: [CPListSection(items: items)])
        interfaceController.setRootTemplate(list, animated: true, completion: nil)
    }
}
