//
//  ColorThemeAdGuideRouter.swift
//  SettingScene
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


protocol ColorThemeAdGuideRouting: Routing {

    func showColorThemeAdGuide(
        _ purpose: ColorThemeAdGuidePurpose,
        licenseDays: Int,
        onFinished: @escaping @Sendable (RewardedAdResult?) -> Void
    )
}


class ColorThemeAdGuideRouter: BaseRouterImple, ColorThemeAdGuideRouting, @unchecked Sendable {

    // 광고 라우터가 해제되면 광고 결과 콜백이 오지 않아 Router 가 붙잡는다
    private let rewardedAdRouter: any RewardedAdRouter
    private let paywallSceneBuilder: any PaywallSceneBuilder
    private let viewAppearance: ViewAppearance

    init(
        rewardedAdRouter: any RewardedAdRouter,
        paywallSceneBuilder: any PaywallSceneBuilder,
        viewAppearance: ViewAppearance
    ) {
        self.rewardedAdRouter = rewardedAdRouter
        self.paywallSceneBuilder = paywallSceneBuilder
        self.viewAppearance = viewAppearance
    }

    func showColorThemeAdGuide(
        _ purpose: ColorThemeAdGuidePurpose,
        licenseDays: Int,
        onFinished: @escaping @Sendable (RewardedAdResult?) -> Void
    ) {
        Task { @MainActor in
            var guideView = ColorThemeAdGuideView(
                purpose: purpose, licenseDays: licenseDays, appearance: self.viewAppearance
            )
            guideView.onWatchAd = { [weak self] in
                self?.dismissPresented(animated: true) { [weak self] in
                    Task { @MainActor in self?.showRewardedAd(onFinished) }
                }
            }
            guideView.onShowPlans = { [weak self] in
                self?.dismissPresented(animated: true) { [weak self] in
                    onFinished(nil)
                    Task { @MainActor in self?.showPaywall() }
                }
            }
            guideView.onClose = { [weak self] in
                self?.dismissPresented(animated: true) { onFinished(nil) }
            }
            self.showBottomSlide(ColorThemeAdGuideViewController(guideView: guideView))
        }
    }

    @MainActor
    private func showRewardedAd(_ onFinished: @escaping @Sendable (RewardedAdResult?) -> Void) {
        guard let scene = self.scene else {
            onFinished(nil)
            return
        }
        self.rewardedAdRouter.showRewardedAd(from: scene) { onFinished($0) }
    }

    @MainActor
    private func showPaywall() {
        let paywall = self.paywallSceneBuilder.makePaywallScene(closesAfterPurchase: true)
        self.showFullScreen(paywall)
    }
}
