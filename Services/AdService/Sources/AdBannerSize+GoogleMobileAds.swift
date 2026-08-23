//
//  AdBannerSize+GoogleMobileAds.swift
//  AdService
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import GoogleMobileAds
import Domain


extension AdBannerSize {

    var asAdSize: AdSize {
        switch self {
        case .banner: return AdSizeBanner
        case .mediumRectangle: return AdSizeMediumRectangle
        }
    }

    var asCGSize: CGSize {
        return cgSize(for: self.asAdSize)
    }
}
