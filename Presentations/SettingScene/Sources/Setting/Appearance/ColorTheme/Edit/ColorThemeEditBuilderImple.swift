//
//  ColorThemeEditBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - ColorThemeEditSceneBuilerImple

final class ColorThemeEditSceneBuilerImple {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let rewardedAdRouter: any RewardedAdRouter
    private let paywallSceneBuilder: any PaywallSceneBuilder

    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        rewardedAdRouter: any RewardedAdRouter,
        paywallSceneBuilder: any PaywallSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.rewardedAdRouter = rewardedAdRouter
        self.paywallSceneBuilder = paywallSceneBuilder
    }
}


extension ColorThemeEditSceneBuilerImple: ColorThemeEditSceneBuiler {

    @MainActor
    func makeColorThemeEditScene(
        original: CustomColorTheme?,
        listener: (any ColorThemeEditSceneListener)?
    ) -> any ColorThemeEditScene {

        let initialSeeds = original?.seeds ?? CustomColorThemeSeeds(
            background: self.viewAppearance.colorSet.bg0.rgbHexString,
            accent: self.viewAppearance.colorSet.accent.rgbHexString,
            form: .filled
        )

        let viewModel = ColorThemeEditViewModelImple(
            original: original,
            initialSeeds: initialSeeds,
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase(),
            paidFeatureGateUsecase: self.usecaseFactory.makeColorThemePaidFeatureGateUsecase()
        )

        let viewController = ColorThemeEditViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )

        let router = ColorThemeEditRouter(
            rewardedAdRouter: self.rewardedAdRouter,
            paywallSceneBuilder: self.paywallSceneBuilder,
            viewAppearance: self.viewAppearance
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener

        return viewController
    }
}
