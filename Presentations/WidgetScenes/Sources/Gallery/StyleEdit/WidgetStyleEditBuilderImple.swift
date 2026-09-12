//
//  WidgetStyleEditBuilderImple.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


final class WidgetStyleEditBuilderImple {
    
    private let widgetStyleUsecase: any WidgetStyleUsecase
    private let viewAppearance: ViewAppearance
    
    init(
        widgetStyleUsecase: any WidgetStyleUsecase,
        viewAppearance: ViewAppearance
    ) {
        self.widgetStyleUsecase = widgetStyleUsecase
        self.viewAppearance = viewAppearance
    }
}

extension WidgetStyleEditBuilderImple: WidgetStyleEditSceneBuilder {
    
    @MainActor
    func makeWidgetStyleEditScene(
        variant: WidgetVariant,
        setting: WidgetAppearanceSettings
    ) -> any WidgetStyleEditScene {
        
        let viewModel = WidgetStyleEditViewModelImple(
            variant: variant, widgetStyleUsecase: self.widgetStyleUsecase
        )
        let viewController = WidgetStyleEditViewController(
            variant: variant,
            setting: setting,
            viewModel: viewModel,
            viewAppearance: viewAppearance
        )
        let router = WidgetStyleEditRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
