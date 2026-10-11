//
//  StubPaidFeatureGateUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubPaidFeatureGateUsecase: PaidFeatureGateUsecase, @unchecked Sendable {

    public init() { }

    public var mockBlockedReason: PaidFeatureGateFailReason?
    public var didCheckFeature: PaidFeature?
    open func check(_ feature: PaidFeature, at now: Date) throws {
        self.didCheckFeature = feature
        guard let mockBlockedReason else { return }
        throw mockBlockedReason
    }

    public var didGrantLicenseWith: (feature: PaidFeature, at: Date)?
    open func grantLicense(for feature: PaidFeature, at now: Date) {
        self.didGrantLicenseWith = (feature, now)
    }
}
