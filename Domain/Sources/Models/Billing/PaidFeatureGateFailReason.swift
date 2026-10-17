//
//  PaidFeatureGateFailReason.swift
//  Domain
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum PaidFeature: Sendable, Equatable {
    case colorTheme(ColorSetKeys)
    case customizeWidget
}


public struct PaidFeatureGateFailReason: Error, Sendable, Equatable {

    public let feature: PaidFeature
    public let licenseDays: Int

    public init(feature: PaidFeature, licenseDays: Int) {
        self.feature = feature
        self.licenseDays = licenseDays
    }
}
