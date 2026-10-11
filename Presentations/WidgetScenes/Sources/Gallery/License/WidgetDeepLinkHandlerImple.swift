//
//  WidgetDeepLinkHandlerImple.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Domain
import Scenes
import CommonPresentation


public final class WidgetDeepLinkHandlerImple: DeepLinkHandler, @unchecked Sendable {

    private let paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase
    private let router: any WidgetLicenseGuideHostRouting
    private let licenseGuide: WidgetStyleLicenseGuide

    init(
        paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase,
        router: any WidgetLicenseGuideHostRouting
    ) {
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
        self.router = router
        self.licenseGuide = .init(paidFeatureGateUsecase: paidFeatureGateUsecase)
        self.licenseGuide.router = router
    }

    public convenience init(
        paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase,
        rewardedAdRouter: any RewardedAdRouter,
        paywallSceneBuilder: any PaywallSceneBuilder,
        topScene: @escaping @MainActor () -> (any Scene)?
    ) {
        self.init(
            paidFeatureGateUsecase: paidFeatureGateUsecase,
            router: WidgetLicenseGuideRouter(
                rewardedAdRouter: rewardedAdRouter,
                paywallSceneBuilder: paywallSceneBuilder,
                topScene: topScene
            )
        )
    }

    public func handleLink(_ link: PendingDeepLink) -> DeepLinkHandleResult {
        var link = link
        switch link.removeFirstPath() {
        case "license":
            self.handleLicenseLink()
            return .handle
        default:
            return .needUpdate
        }
    }

    /// 권한이 이미 있는데 잠김 링크로 들어왔으면 위젯이 낡은 잠김을 그린 것이라 다시 그리기만 한다
    private func handleLicenseLink() {
        guard self.paidFeatureGateUsecase.canCreateCustomWidgetStyleWithoutAd(at: Date()) == false
        else {
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        Task { @MainActor [weak self] in
            guard let self, self.router.attachTopScene() else { return }
            self.licenseGuide.show { }
        }
    }
}

