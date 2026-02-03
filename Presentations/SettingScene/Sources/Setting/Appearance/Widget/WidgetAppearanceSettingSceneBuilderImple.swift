//
//  WidgetAppearanceSettingSceneBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 2/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


final class WidgetAppearanceSettingSceneBuilderImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}

extension WidgetAppearanceSettingSceneBuilderImple: WidgetAppearanceSettingSceneBuilder {
    
    @MainActor
    func makeWidgetAppearanceSettingScene(
        setting: WidgetAppearanceSettings
    ) -> any WidgetAppearanceSettingScene {
        
        let viewModel = WidgetAppearanceSettingViewModelImple(
            setting: setting, uiSettingUsecase: usecaseFactory.makeUISettingUsecase()
        )
        let viewController = WidgetAppearanceSettingViewController(viewModel: viewModel, viewAppearance: viewAppearance)
        let router = WidgetAppearanceSettingRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
