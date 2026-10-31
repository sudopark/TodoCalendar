//
//  ColorThemeEditBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import BillingSceneInterface
import SceneInfra
import SettingDomainInterface


// MARK: - ColorThemeEditSceneBuilerImple

final class ColorThemeEditSceneBuilerImple {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder

    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.adGuideSceneBuilder = adGuideSceneBuilder
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
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase()
        )

        let viewController = ColorThemeEditViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )

        let router = ColorThemeEditRouter(
            adGuideSceneBuilder: self.adGuideSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener

        return viewController
    }
}
