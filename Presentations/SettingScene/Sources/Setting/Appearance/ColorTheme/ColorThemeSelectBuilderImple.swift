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
import Scenes
import CommonPresentation


// MARK: - ColorThemeSelectSceneBuilerImple

final class ColorThemeSelectSceneBuilerImple {
    
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
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
