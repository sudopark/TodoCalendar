//
//  RewardedAdLicenseDecision.swift
//  Domain
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum RewardedAdLicenseDecision: Sendable, Equatable {
    case grantLicenseAndContinue
    case continueWithoutLicense
    case notifyAdUnavailable
    case cancel
}
