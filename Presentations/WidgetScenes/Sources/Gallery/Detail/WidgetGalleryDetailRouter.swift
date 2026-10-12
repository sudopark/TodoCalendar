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

    func showPaidFeatureAdGuide(
        _ reason: PaidFeatureGateFailReason, onFinished: @escaping @Sendable (Bool) -> Void
    )
    
    func routeToStyleEdit(_ variants: [WidgetVariant], setting: WidgetAppearanceSettings)
}

final class WidgetGalleryDetailRouter: BaseRouterImple, WidgetGalleryDetailRouting, @unchecked Sendable {
    
    private let styleEditSceneBuilder: any WidgetStyleEditSceneBuilder
    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    
    init(
        styleEditSceneBuilder: any WidgetStyleEditSceneBuilder,
        adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    ) {
        self.styleEditSceneBuilder = styleEditSceneBuilder
        self.adGuideSceneBuilder = adGuideSceneBuilder
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
    
    func routeToStyleEdit(_ variants: [WidgetVariant], setting: WidgetAppearanceSettings) {
        Task { @MainActor in
            let next = self.styleEditSceneBuilder.makeWidgetStyleEditScene(
                variants: variants, setting: setting
            )
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }

    func showPaidFeatureAdGuide(
        _ reason: PaidFeatureGateFailReason, onFinished: @escaping @Sendable (Bool) -> Void
    ) {
        Task { @MainActor in
            let guide = self.adGuideSceneBuilder.makePaidFeatureAdGuideScene(
                reason: reason, onFinished: onFinished, onUseDefault: nil
            )
            self.showBottomSlide(guide)
        }
    }
}
