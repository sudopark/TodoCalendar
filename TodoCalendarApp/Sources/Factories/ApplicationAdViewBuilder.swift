//
//  ApplicationAdViewBuilder.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Domain
import CommonPresentation
import AdService


final class ApplicationAdViewBuilder: AdViewBuilder {

    private let adService: GoogleMobileAdsServiceImple
    private let billingUsecase: any BillingUsecase

    init(adService: GoogleMobileAdsServiceImple, billingUsecase: any BillingUsecase) {
        self.adService = adService
        self.billingUsecase = billingUsecase
    }
    
    private struct BannerRequest {
        let adUnitId: String
        let size: AdService.AdBannerSize
    }

    private func bannerRequest(for size: CommonPresentation.AdBannerSize) -> BannerRequest {
        switch size {
        case .banner:
            return BannerRequest(adUnitId: AppEnvironment.admobUnitIds.banner, size: .banner)
        case .mediumRectangle:
            return BannerRequest(adUnitId: AppEnvironment.admobUnitIds.mediumRectangle, size: .mediumRectangle)
        }
    }

    @MainActor
    func makeBannerView(size: CommonPresentation.AdBannerSize) -> any View {
        let request = self.bannerRequest(for: size)
        return AdBannerView(
            adUnitId: request.adUnitId,
            size: request.size,
            adService: self.adService,
            billingUsecase: self.billingUsecase
        )
    }

    @MainActor
    func makeBannerUIView(size: CommonPresentation.AdBannerSize) -> UIView {
        let request = self.bannerRequest(for: size)
        return AdBannerUIView(
            adUnitId: request.adUnitId,
            size: request.size,
            adService: self.adService,
            billingUsecase: self.billingUsecase
        )
    }
}
