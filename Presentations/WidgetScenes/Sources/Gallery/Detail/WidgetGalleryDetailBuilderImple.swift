//
//  WidgetGalleryDetailBuilderImple.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


final class WidgetGalleryDetailBuilderImple {
    
    private let widgetStyleUsecase: any WidgetStyleUsecase
    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    private let viewAppearance: ViewAppearance
    
    init(
        widgetStyleUsecase: any WidgetStyleUsecase,
        adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder,
        viewAppearance: ViewAppearance
    ) {
        self.widgetStyleUsecase = widgetStyleUsecase
        self.adGuideSceneBuilder = adGuideSceneBuilder
        self.viewAppearance = viewAppearance
    }
}

extension WidgetGalleryDetailBuilderImple: WidgetGalleryDetailSceneBuilder {
    
    @MainActor
    func makeWidgetGalleryDetailScene(
        item: WidgetGalleryItem,
        setting: WidgetAppearanceSettings
    ) -> any WidgetGalleryDetailScene {
        
        let viewModel = WidgetGalleryDetailViewModelImple(
            item: item, setting: setting, widgetStyleUsecase: self.widgetStyleUsecase
        )
        let viewController = WidgetGalleryDetailViewController(
            viewModel: viewModel, viewAppearance: viewAppearance
        )
        let router = WidgetGalleryDetailRouter(
            styleEditSceneBuilder: WidgetStyleEditBuilderImple(
                widgetStyleUsecase: self.widgetStyleUsecase,
                adGuideSceneBuilder: self.adGuideSceneBuilder,
                viewAppearance: viewAppearance
            )
        )
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
