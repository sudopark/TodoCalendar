//
//  MobileAdService.swift
//  AdService
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import GoogleMobileAds
import Domain


public protocol MobileAdService: MobileAdAvailability {

    func start()

    @MainActor
    func presentConsentFormAndTrackingPromptIfNeeded(from viewController: UIViewController) async

    func preloadFullScreenAd() async

    func takePreloadedFullScreenAd() -> InterstitialAd?

    @MainActor
    func isPrivacyOptionsRequired() -> Bool

    @MainActor
    func showPrivacyOptionsForm(from viewController: UIViewController) async throws
}
