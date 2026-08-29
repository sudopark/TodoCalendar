//
//  FullScreenAdRouterImple.swift
//  AdService
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import GoogleMobileAds
import Domain
import Extensions


public final class FullScreenAdRouterImple: NSObject, @unchecked Sendable {

    private let adService: any MobileAdService
    private let adExposureUsecase: any AdExposureUsecase
    @MainActor private var presentingAd: InterstitialAd?

    public init(
        adService: any MobileAdService,
        adExposureUsecase: any AdExposureUsecase
    ) {
        self.adService = adService
        self.adExposureUsecase = adExposureUsecase
        super.init()
    }

    @MainActor
    public func show(
        from viewController: UIViewController,
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool
    ) {
        let now = Date()
        guard self.adExposureUsecase.canExposeFullScreenAd(
            scope: scope, isFromAppLaunch: isFromAppLaunch, at: now
        ), let ad = self.adService.takePreloadedFullScreenAd()
        else { return }

        ad.fullScreenContentDelegate = self
        self.presentingAd = ad
        ad.present(from: viewController)
        self.adExposureUsecase.recordFullScreenAdExposed(scope: scope, at: now)
    }
}


// MARK: - FullScreenContentDelegate

extension FullScreenAdRouterImple: FullScreenContentDelegate {

    public func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        self.presentingAd = nil
        Task { [weak self] in
            await self?.adService.preloadFullScreenAd()
        }
    }

    public func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        self.presentingAd = nil
        logger.log(level: .error, "interstitial ad present failed: \(error)")
        Task { [weak self] in
            await self?.adService.preloadFullScreenAd()
        }
    }
}
