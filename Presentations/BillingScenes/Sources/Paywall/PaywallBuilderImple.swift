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
    private let showManageSubscriptions: @MainActor @Sendable (UIWindowScene) async throws -> Void

    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        showManageSubscriptions: @escaping @MainActor @Sendable (UIWindowScene) async throws -> Void
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.showManageSubscriptions = showManageSubscriptions
    }

    @MainActor
    public func makePaywallScene() -> any PaywallScene {
        let viewModel = PaywallViewModelImple(billingUsecase: self.usecaseFactory.billingUsecase)
        let viewController = PaywallViewController(viewModel: viewModel, viewAppearance: self.viewAppearance)
        let router = PaywallRouter(showManageSubscriptionsSheet: self.showManageSubscriptions)
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
