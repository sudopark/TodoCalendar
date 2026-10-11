//
//  WidgetGalleryDetailBuilderImple.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


final class WidgetGalleryDetailBuilderImple {
    
    private let widgetStyleUsecase: any WidgetStyleUsecase
    private let paidFeatureGateUsecase: any PaidFeatureGateUsecase
    private let paywallSceneBuilder: any PaywallSceneBuilder
    private let rewardedAdRouter: any RewardedAdRouter
    private let viewAppearance: ViewAppearance
    
    init(
        widgetStyleUsecase: any WidgetStyleUsecase,
        paidFeatureGateUsecase: any PaidFeatureGateUsecase,
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

extension WidgetGalleryDetailBuilderImple: WidgetGalleryDetailSceneBuilder {
    
    @MainActor
    func makeWidgetGalleryDetailScene(
        item: WidgetGalleryItem,
        setting: WidgetAppearanceSettings
    ) -> any WidgetGalleryDetailScene {
        
        let viewModel = WidgetGalleryDetailViewModelImple(
            item: item, setting: setting, widgetStyleUsecase: self.widgetStyleUsecase
        )
        let viewController = WidgetGalleryDetailViewController(
            viewModel: viewModel, viewAppearance: viewAppearance
        )
        let router = WidgetGalleryDetailRouter(
            styleEditSceneBuilder: WidgetStyleEditBuilderImple(
                widgetStyleUsecase: self.widgetStyleUsecase,
                paidFeatureGateUsecase: self.paidFeatureGateUsecase,
                paywallSceneBuilder: self.paywallSceneBuilder,
                rewardedAdRouter: self.rewardedAdRouter,
                viewAppearance: viewAppearance
            )
        )
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
