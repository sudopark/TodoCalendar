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
    
    private let viewAppearance: ViewAppearance
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
}

extension WidgetGalleryDetailBuilderImple: WidgetGalleryDetailSceneBuilder {
    
    @MainActor
    func makeWidgetGalleryDetailScene(
        item: WidgetGalleryItem,
        setting: WidgetAppearanceSettings
    ) -> any WidgetGalleryDetailScene {
        
        let viewModel = WidgetGalleryDetailViewModelImple(item: item, setting: setting)
        let viewController = WidgetGalleryDetailViewController(
            viewModel: viewModel, viewAppearance: viewAppearance
        )
        let router = WidgetGalleryDetailRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
