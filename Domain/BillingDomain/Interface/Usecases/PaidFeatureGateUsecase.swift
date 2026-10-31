//
//  PaidFeatureGateUsecase.swift
//  BillingDomainInterface
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public protocol PaidFeatureGateUsecase: Sendable {

    func check(_ feature: PaidFeature, at now: Date) throws
    func grantLicense(for feature: PaidFeature, at now: Date)
}
