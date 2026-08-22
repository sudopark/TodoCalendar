//
//  ApplicationAdViewBuilder.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import CommonPresentation
import AdService


final class ApplicationAdViewBuilder: AdViewBuilder {

    private let adService: GoogleMobileAdsServiceImple
    private let gate: AdDisplayGate

    init(adService: GoogleMobileAdsServiceImple, gate: AdDisplayGate) {
        self.adService = adService
        self.gate = gate
    }
    
    private struct BannerRequest {
        let adUnitId: String
        let size: AdBannerSize
    }
    
    private func bannerRequest(for placement: AdBannerPlacement) -> BannerRequest {
        switch placement {
        case .calendarBottom:
            return BannerRequest(
                adUnitId: AppEnvironment.admobUnitIds.calendarBottomBanner,
                size: .banner
            )
        case .aiCommandProcessing:
            return BannerRequest(
                adUnitId: AppEnvironment.admobUnitIds.aiCommandMediumRectangle,
                size: .mediumRectangle
            )
        }
    }
    
    @MainActor
    func makeBannerView(for placement: AdBannerPlacement) -> any View {
        let request = self.bannerRequest(for: placement)
        return GatedAdBannerView(canShowAd: self.gate.canShowAd) {
            AdBannerView(
                adUnitId: request.adUnitId,
                size: request.size,
                adService: self.adService
            )
        }
    }

    @MainActor
    func makeBannerUIView(for placement: AdBannerPlacement) -> UIView {
        let request = self.bannerRequest(for: placement)
        return GatedAdBannerUIView(canShowAd: self.gate.canShowAd) {
            AdBannerUIView(
                adUnitId: request.adUnitId,
                size: request.size,
                adService: self.adService
            )
        }
    }
}
