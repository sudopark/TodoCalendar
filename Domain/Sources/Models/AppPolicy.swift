//
//  AppPolicy.swift
//  Domain
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct AppPolicy: Equatable, Sendable {

    public var colorThemeLicense: ColorThemeLicensePolicy?
    public var widgetStyleLicense: WidgetStyleLicensePolicy?
    public var featureSwitches: [String: FeatureSwitch]

    public init(
        colorThemeLicense: ColorThemeLicensePolicy? = nil,
        widgetStyleLicense: WidgetStyleLicensePolicy? = nil,
        featureSwitches: [String: FeatureSwitch] = [:]
    ) {
        self.colorThemeLicense = colorThemeLicense
        self.widgetStyleLicense = widgetStyleLicense
        self.featureSwitches = featureSwitches
    }
}


public struct FeatureSwitch: Equatable, Sendable {

    public let isEnabled: Bool
    public var minAppVersion: String?
    public var rolloutPercentage: Int?

    public init(isEnabled: Bool, minAppVersion: String? = nil, rolloutPercentage: Int? = nil) {
        self.isEnabled = isEnabled
        self.minAppVersion = minAppVersion
        self.rolloutPercentage = rolloutPercentage
    }
}
