//
//  WidgetLicenseGuideRouter.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


protocol WidgetLicenseGuideHostRouting: WidgetStyleLicenseGuideRouting {

    @MainActor func attachTopScene() -> Bool
}

final class WidgetLicenseGuideRouter: BaseRouterImple, WidgetLicenseGuideHostRouting, @unchecked Sendable {

    // 광고 라우터가 해제되면 광고 결과 콜백이 오지 않아 Router 가 붙잡는다
    private let rewardedAdRouter: any RewardedAdRouter
    private let paywallSceneBuilder: any PaywallSceneBuilder
    private let topScene: @MainActor () -> (any Scene)?

    init(
        rewardedAdRouter: any RewardedAdRouter,
        paywallSceneBuilder: any PaywallSceneBuilder,
        topScene: @escaping @MainActor () -> (any Scene)?
    ) {
        self.rewardedAdRouter = rewardedAdRouter
        self.paywallSceneBuilder = paywallSceneBuilder
        self.topScene = topScene
    }

    @MainActor
    func attachTopScene() -> Bool {
        self.scene = self.topScene()
        return self.scene != nil
    }

    func routeToRewardedAd(completion: @escaping @Sendable (RewardedAdResult) -> Void) {
        Task { @MainActor in
            guard let scene = self.scene else {
                completion(.dismissedBeforeReward)
                return
            }
            self.rewardedAdRouter.showRewardedAd(from: scene) { completion($0) }
        }
    }

    func routeToPaywall() {
        Task { @MainActor in
            let paywall = self.paywallSceneBuilder.makePaywallScene(closesAfterPurchase: true)
            self.showFullScreen(paywall)
        }
    }
}
