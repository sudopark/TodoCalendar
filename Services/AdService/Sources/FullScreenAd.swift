//
//  FullScreenAd.swift
//  AdService
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import GoogleMobileAds
import Extensions
import Domain


public final class FullScreenAd: NSObject, @unchecked Sendable {

    private let adUnitId: String
    private let adService: GoogleMobileAdsServiceImple
    private let billingUsecase: any BillingUsecase
    @MainActor private var presentingAd: InterstitialAd?

    public init(
        adUnitId: String,
        adService: GoogleMobileAdsServiceImple,
        billingUsecase: any BillingUsecase
    ) {
        self.adUnitId = adUnitId
        self.adService = adService
        self.billingUsecase = billingUsecase
        super.init()
    }

    @MainActor
    public func show(from viewController: UIViewController) async throws {
        // 게이팅은 에러가 아니라 정상적인 "안 띄움" 이다 — throw 하지 않는다
        guard self.adService.isStartedNow,
              self.billingUsecase.latestUserPlan()?.planId == .free
        else { return }

        let ad = try await InterstitialAd.load(with: self.adUnitId, request: Request())
        ad.fullScreenContentDelegate = self
        // 노출 중 광고 객체가 해제되면 SDK 가 화면을 걷어간다
        self.presentingAd = ad
        ad.present(from: viewController)
    }
}


// MARK: - FullScreenContentDelegate

extension FullScreenAd: FullScreenContentDelegate {
    
    public func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        self.presentingAd = nil
    }
    
    public func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        self.presentingAd = nil
        logger.log(level: .error, "interstitial ad present failed: \(error)")
    }
}
