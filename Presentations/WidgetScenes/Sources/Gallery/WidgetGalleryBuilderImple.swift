//
//  WidgetGalleryBuilderImple.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


public final class WidgetGalleryBuilderImple {

    private let uiSettingUsecase: any UISettingUsecase
    private let viewAppearance: ViewAppearance

    public init(
        uiSettingUsecase: any UISettingUsecase,
        viewAppearance: ViewAppearance
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.viewAppearance = viewAppearance
    }
}

extension WidgetGalleryBuilderImple: WidgetGallerySceneBuilder {
    
    @MainActor
    public func makeWidgetGalleryScene(
        setting: WidgetAppearanceSettings
    ) -> any WidgetGalleryScene {
        
        let viewModel = WidgetGalleryViewModelImple(
            setting: setting, uiSettingUsecase: self.uiSettingUsecase
        )
        let viewController = WidgetGalleryViewController(
            viewModel: viewModel, viewAppearance: viewAppearance
        )
        let router = WidgetGalleryRouter(
            detailSceneBuilder: WidgetGalleryDetailBuilderImple(viewAppearance: viewAppearance)
        )
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
