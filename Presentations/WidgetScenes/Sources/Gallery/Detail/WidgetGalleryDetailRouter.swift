//
//  WidgetGalleryDetailRouter.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


protocol WidgetGalleryDetailRouting: Routing {
    
    func routeToStyleEdit(_ variant: WidgetVariant, setting: WidgetAppearanceSettings)
}

final class WidgetGalleryDetailRouter: BaseRouterImple, WidgetGalleryDetailRouting, @unchecked Sendable {
    
    private let styleEditSceneBuilder: any WidgetStyleEditSceneBuilder
    
    init(styleEditSceneBuilder: any WidgetStyleEditSceneBuilder) {
        self.styleEditSceneBuilder = styleEditSceneBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
    
    private var currentScene: (any WidgetGalleryDetailScene)? {
        self.scene as? (any WidgetGalleryDetailScene)
    }
}


extension WidgetGalleryDetailRouter {
    
    func routeToStyleEdit(_ variant: WidgetVariant, setting: WidgetAppearanceSettings) {
        Task { @MainActor in
            let next = self.styleEditSceneBuilder.makeWidgetStyleEditScene(
                variant: variant, setting: setting
            )
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
