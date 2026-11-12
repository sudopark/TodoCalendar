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
    public var mainBannerExposure: MainBannerExposurePolicy?
    public var fullScreenAdEventSaveInterval: Int?
    public var featureSwitches: [String: FeatureSwitch]

    public init(
        colorThemeLicense: ColorThemeLicensePolicy? = nil,
        widgetStyleLicense: WidgetStyleLicensePolicy? = nil,
        mainBannerExposure: MainBannerExposurePolicy? = nil,
        fullScreenAdEventSaveInterval: Int? = nil,
        featureSwitches: [String: FeatureSwitch] = [:]
    ) {
        self.colorThemeLicense = colorThemeLicense
        self.widgetStyleLicense = widgetStyleLicense
        self.mainBannerExposure = mainBannerExposure
        self.fullScreenAdEventSaveInterval = fullScreenAdEventSaveInterval
        self.featureSwitches = featureSwitches
    }
}


public struct MainBannerExposurePolicy: Equatable, Sendable {

    public var exposurePercentage: Int?
    public var minDelaySeconds: Int?
    public var maxDelaySeconds: Int?

    public init(
        exposurePercentage: Int? = nil,
        minDelaySeconds: Int? = nil,
        maxDelaySeconds: Int? = nil
    ) {
        self.exposurePercentage = exposurePercentage
        self.minDelaySeconds = minDelaySeconds
        self.maxDelaySeconds = maxDelaySeconds
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
