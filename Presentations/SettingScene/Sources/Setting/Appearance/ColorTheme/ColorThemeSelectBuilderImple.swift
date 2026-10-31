//
//  
//  ColorThemeSelectBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 8/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import CommonPresentation
import BillingSceneInterface
import SceneInfra


// MARK: - ColorThemeSelectSceneBuilerImple

final class ColorThemeSelectSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let editSceneBuilder: any ColorThemeEditSceneBuiler
    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        editSceneBuilder: any ColorThemeEditSceneBuiler,
        adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.editSceneBuilder = editSceneBuilder
        self.adGuideSceneBuilder = adGuideSceneBuilder
    }
}


extension ColorThemeSelectSceneBuilerImple: ColorThemeSelectSceneBuiler {
    
    @MainActor
    func makeColorThemeSelectScene() -> any ColorThemeSelectScene {
        
        let viewModel = ColorThemeSelectViewModelImple(
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase()
        )
        
        let viewController = ColorThemeSelectViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = ColorThemeSelectRouter(
            editSceneBuilder: self.editSceneBuilder,
            adGuideSceneBuilder: self.adGuideSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
