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
    
    init(adService: GoogleMobileAdsServiceImple) {
        self.adService = adService
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
        return AdBannerView(
            adUnitId: request.adUnitId,
            size: request.size,
            adService: self.adService
        )
    }
    
    @MainActor
    func makeBannerUIView(for placement: AdBannerPlacement) -> UIView {
        let request = self.bannerRequest(for: placement)
        return AdBannerUIView(
            adUnitId: request.adUnitId,
            size: request.size,
            adService: self.adService
        )
    }
}
