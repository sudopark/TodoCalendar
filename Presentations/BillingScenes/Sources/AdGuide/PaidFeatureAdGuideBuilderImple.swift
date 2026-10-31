//
//  PaidFeatureAdGuideBuilderImple.swift
//  BillingScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import BillingDomainInterface
import BillingSceneInterface
import SceneInfra


public final class PaidFeatureAdGuideBuilderImple: PaidFeatureAdGuideSceneBuilder {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let rewardedAdRouter: any RewardedAdRouter
    private let paywallSceneBuilder: any PaywallSceneBuilder

    public init(
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

    @MainActor
    public func makePaidFeatureAdGuideScene(
        reason: PaidFeatureGateFailReason,
        onFinished: @escaping @Sendable (Bool) -> Void,
        onUseDefault: (@Sendable () -> Void)?
    ) -> UIViewController {
        let viewModel = PaidFeatureAdGuideViewModelImple(
            reason: reason,
            paidFeatureGateUsecase: self.usecaseFactory.makePaidFeatureGateUsecase(),
            accountUsecase: self.usecaseFactory.accountUescase,
            onFinished: onFinished,
            onUseDefault: onUseDefault
        )
        let viewController = PaidFeatureAdGuideViewController(
            viewModel: viewModel, viewAppearance: self.viewAppearance
        )
        let router = PaidFeatureAdGuideRouter(
            rewardedAdRouter: self.rewardedAdRouter,
            paywallSceneBuilder: self.paywallSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
