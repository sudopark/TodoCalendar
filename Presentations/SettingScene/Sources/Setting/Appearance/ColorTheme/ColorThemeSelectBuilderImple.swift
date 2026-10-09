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
    private let editSceneBuilder: any ColorThemeEditSceneBuiler
    private let rewardedAdRouter: any RewardedAdRouter
    private let paywallSceneBuilder: any PaywallSceneBuilder
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        editSceneBuilder: any ColorThemeEditSceneBuiler,
        rewardedAdRouter: any RewardedAdRouter,
        paywallSceneBuilder: any PaywallSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.editSceneBuilder = editSceneBuilder
        self.rewardedAdRouter = rewardedAdRouter
        self.paywallSceneBuilder = paywallSceneBuilder
    }
}


extension ColorThemeSelectSceneBuilerImple: ColorThemeSelectSceneBuiler {
    
    @MainActor
    func makeColorThemeSelectScene() -> any ColorThemeSelectScene {
        
        let viewModel = ColorThemeSelectViewModelImple(
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase(),
            paidFeatureGateUsecase: self.usecaseFactory.makeColorThemePaidFeatureGateUsecase()
        )
        
        let viewController = ColorThemeSelectViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = ColorThemeSelectRouter(
            editSceneBuilder: self.editSceneBuilder,
            rewardedAdRouter: self.rewardedAdRouter,
            paywallSceneBuilder: self.paywallSceneBuilder,
            viewAppearance: self.viewAppearance
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
