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

    private let adExposureUsecase: any AdExposureUsecase

    init(adExposureUsecase: any AdExposureUsecase) {
        self.adExposureUsecase = adExposureUsecase
    }

    private func adUnitId(for size: AdBannerSize) -> String {
        switch size {
        case .banner: return AppEnvironment.admobUnitIds.banner
        case .mediumRectangle: return AppEnvironment.admobUnitIds.mediumRectangle
        }
    }

    @MainActor
    func makeBannerView(size: AdBannerSize) -> any View {
        return AdBannerView(
            adUnitId: self.adUnitId(for: size),
            size: size,
            adExposureUsecase: self.adExposureUsecase
        )
    }

    @MainActor
    func makeBannerUIView(size: AdBannerSize) -> UIView {
        return AdBannerUIView(
            adUnitId: self.adUnitId(for: size),
            size: size,
            adExposureUsecase: self.adExposureUsecase
        )
    }
}
