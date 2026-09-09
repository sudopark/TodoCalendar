//
//  WidgetGalleryRouter.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


protocol WidgetGalleryRouting: Routing {
    
    func routeToDetail(_ item: WidgetGalleryItem, setting: WidgetAppearanceSettings)
}

final class WidgetGalleryRouter: BaseRouterImple, WidgetGalleryRouting, @unchecked Sendable {
    
    private let detailSceneBuilder: any WidgetGalleryDetailSceneBuilder
    
    init(detailSceneBuilder: any WidgetGalleryDetailSceneBuilder) {
        self.detailSceneBuilder = detailSceneBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
    
    private var currentScene: (any WidgetGalleryScene)? {
        self.scene as? (any WidgetGalleryScene)
    }
}

extension WidgetGalleryRouter {
    
    func routeToDetail(_ item: WidgetGalleryItem, setting: WidgetAppearanceSettings) {
        Task { @MainActor in
            let next = self.detailSceneBuilder.makeWidgetGalleryDetailScene(
                item: item, setting: setting
            )
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
