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
    private let widgetStyleUsecase: any WidgetStyleUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    private let viewAppearance: ViewAppearance

    public init(
        uiSettingUsecase: any UISettingUsecase,
        widgetStyleUsecase: any WidgetStyleUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder,
        viewAppearance: ViewAppearance
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.widgetStyleUsecase = widgetStyleUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.adGuideSceneBuilder = adGuideSceneBuilder
        self.viewAppearance = viewAppearance
    }
}

extension WidgetGalleryBuilderImple: WidgetGallerySceneBuilder {
    
    @MainActor
    public func makeWidgetGalleryScene(
        setting: WidgetAppearanceSettings
    ) -> any WidgetGalleryScene {
        
        let viewModel = WidgetGalleryViewModelImple(
            setting: setting,
            uiSettingUsecase: self.uiSettingUsecase,
            widgetStyleUsecase: self.widgetStyleUsecase,
            calendarSettingUsecase: self.calendarSettingUsecase
        )
        let viewController = WidgetGalleryViewController(
            viewModel: viewModel, viewAppearance: viewAppearance
        )
        let router = WidgetGalleryRouter(
            detailSceneBuilder: WidgetGalleryDetailBuilderImple(
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
