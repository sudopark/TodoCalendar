//
//  AdBannerSize.swift
//  AdService
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import GoogleMobileAds


public enum AdBannerSize: Sendable {
    case banner
    case mediumRectangle
    
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
