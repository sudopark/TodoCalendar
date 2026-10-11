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
    private let paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase
    private let paywallSceneBuilder: any PaywallSceneBuilder
    private let rewardedAdRouter: any RewardedAdRouter
    private let viewAppearance: ViewAppearance
    
    init(
        widgetStyleUsecase: any WidgetStyleUsecase,
        paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase,
        paywallSceneBuilder: any PaywallSceneBuilder,
        rewardedAdRouter: any RewardedAdRouter,
        viewAppearance: ViewAppearance
    ) {
        self.widgetStyleUsecase = widgetStyleUsecase
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
        self.paywallSceneBuilder = paywallSceneBuilder
        self.rewardedAdRouter = rewardedAdRouter
        self.viewAppearance = viewAppearance
    }
}

extension WidgetStyleEditBuilderImple: WidgetStyleEditSceneBuilder {
    
    @MainActor
    func makeWidgetStyleEditScene(
        variants: [WidgetVariant],
        setting: WidgetAppearanceSettings
    ) -> any WidgetStyleEditScene {
        
        let viewModel = WidgetStyleEditViewModelImple(
            variants: variants,
            widgetStyleUsecase: self.widgetStyleUsecase,
            paidFeatureGateUsecase: self.paidFeatureGateUsecase
        )
        let viewController = WidgetStyleEditViewController(
            variants: variants,
            setting: setting,
            viewModel: viewModel,
            viewAppearance: viewAppearance
        )
        let router = WidgetStyleEditRouter(
            paywallSceneBuilder: self.paywallSceneBuilder,
            rewardedAdRouter: self.rewardedAdRouter
        )
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
