//
//  PaywallBuilderImple.swift
//  BillingScenes
//
//  Created by sudo.park on 8/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


public final class PaywallBuilderImple: PaywallSceneBuilder {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance

    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }

    @MainActor
    public func makePaywallScene() -> any PaywallScene {
        let viewModel = PaywallViewModelImple(billingUsecase: self.usecaseFactory.billingUsecase)
        let viewController = PaywallViewController(viewModel: viewModel, viewAppearance: self.viewAppearance)
        let router = PaywallRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
