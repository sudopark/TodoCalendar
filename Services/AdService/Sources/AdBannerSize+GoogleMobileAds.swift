//
//  AdBannerSize+GoogleMobileAds.swift
//  AdService
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import GoogleMobileAds
import AdDomainInterface


extension AdBannerSize {

    // SDK 는 화면 짧은 변을 넘는 폭을 "Ad size will not fit on screen" 으로 거부한다 — 가로가 긴 화면에서 걸린다
    func adSize(fittingWidth width: CGFloat, within screenSize: CGSize) -> AdSize? {
        switch self {
        case .banner:
            let limit = min(screenSize.width, screenSize.height)
            guard width > 0, limit > 0 else { return nil }
            return currentOrientationAnchoredAdaptiveBanner(width: min(width, limit))
        case .mediumRectangle:
            return AdSizeMediumRectangle
        }
    }
}
