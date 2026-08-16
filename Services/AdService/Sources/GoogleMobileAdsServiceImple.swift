//
//  GoogleMobileAdsServiceImple.swift
//  AdService
//
//  Created by sudo.park on 8/16/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import GoogleMobileAds
import Domain


public final class GoogleMobileAdsServiceImple: MobileAdService {

    public init() { }

    public func prepare() async {
        _ = await MobileAds.shared.start()
    }

    public func loadRewardedAd(unitId: String) async throws {
        _ = try await RewardedAd.load(with: unitId, request: Request())
    }
}
