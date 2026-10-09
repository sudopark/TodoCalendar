//
//  StubColorThemePaidFeatureGateUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubColorThemePaidFeatureGateUsecase: ColorThemePaidFeatureGateUsecase, @unchecked Sendable {

    public init() { }

    public var canApplyWithoutAd: Bool = true
    public var didAskCanApplyWithKey: ColorSetKeys?
    open func canApplyColorThemeWithoutAd(_ key: ColorSetKeys, at now: Date) -> Bool {
        self.didAskCanApplyWithKey = key
        return self.canApplyWithoutAd
    }

    public var licenseDays: Int? = 7
    open func colorThemeLicenseDays() -> Int? {
        return self.licenseDays
    }

    open func colorThemeAdOutcome(for result: RewardedAdResult) -> ColorThemeAdOutcome {
        switch result {
        case .rewarded, .fallbackFullScreenShown: return .grantLicenseAndProceed
        case .unavailable: return .proceedWithoutLicense
        case .dismissedBeforeReward: return .stop
        }
    }

    public var didGrantLicenseAt: Date?
    open func grantColorThemeLicense(at now: Date) {
        self.didGrantLicenseAt = now
    }
}
