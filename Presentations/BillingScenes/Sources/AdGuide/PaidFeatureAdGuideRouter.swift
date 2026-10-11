//
//  PaidFeatureAdGuideRouter.swift
//  BillingScenes
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - PaidFeatureAdGuideRouting

protocol PaidFeatureAdGuideRouting: Routing, Sendable {

    func routeToRewardedAd(_ completion: @escaping @Sendable (RewardedAdResult) -> Void)
    func routeToPaywall()
}


// MARK: - PaidFeatureAdGuideRouter

final class PaidFeatureAdGuideRouter: BaseRouterImple, PaidFeatureAdGuideRouting, @unchecked Sendable {

    // 광고 라우터가 해제되면 광고 결과 콜백이 오지 않아 Router 가 붙잡는다
    private let rewardedAdRouter: any RewardedAdRouter
    private let paywallSceneBuilder: any PaywallSceneBuilder

    init(
        rewardedAdRouter: any RewardedAdRouter,
        paywallSceneBuilder: any PaywallSceneBuilder
    ) {
        self.rewardedAdRouter = rewardedAdRouter
        self.paywallSceneBuilder = paywallSceneBuilder
    }
}


// MARK: - 광고·paywall

extension PaidFeatureAdGuideRouter {

    func routeToRewardedAd(_ completion: @escaping @Sendable (RewardedAdResult) -> Void) {
        Task { @MainActor in
            guard let sheet = self.scene else {
                completion(.dismissedBeforeReward)
                return
            }
            self.rewardedAdRouter.showRewardedAd(from: sheet) { completion($0) }
        }
    }

    func routeToPaywall() {
        Task { @MainActor in
            let presenter = self.scene?.presentingViewController
            self.scene?.dismiss(animated: true) {
                let paywall = self.paywallSceneBuilder.makePaywallScene(closesAfterPurchase: true)
                paywall.modalPresentationStyle = .overFullScreen
                presenter?.present(paywall, animated: true)
            }
        }
    }
}
