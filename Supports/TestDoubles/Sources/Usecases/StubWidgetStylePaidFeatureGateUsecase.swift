//
//  StubWidgetStylePaidFeatureGateUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubWidgetStylePaidFeatureGateUsecase: WidgetStylePaidFeatureGateUsecase, @unchecked Sendable {

    public init() { }

    public var canCreateWithoutAd: Bool = true
    open func canCreateCustomWidgetStyleWithoutAd(at now: Date) -> Bool {
        return self.canCreateWithoutAd
    }

    public var canRender: Bool = true
    open func canRenderCustomWidgetStyle(at now: Date) -> Bool {
        return self.canRender
    }

    public var licenseDays: Int? = 7
    open func widgetStyleLicenseDays() -> Int? {
        return self.licenseDays
    }

    open func widgetStyleLicenseDecision(for result: RewardedAdResult) -> RewardedAdLicenseDecision {
        switch result {
        case .rewarded, .fallbackFullScreenShown: return .grantLicenseAndContinue
        case .unavailable: return .notifyAdUnavailable
        case .dismissedBeforeReward: return .cancel
        }
    }

    public var didGrantLicenseAt: Date?
    open func grantCustomWidgetStyleLicense(at now: Date) {
        self.didGrantLicenseAt = now
    }
}
