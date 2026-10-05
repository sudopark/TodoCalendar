//
//  AppPolicy+Mapping.swift
//  Repository
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


struct AppPolicyMapper: Codable {

    private enum CodingKeys: String, CodingKey {
        case colorThemeLicense = "color_theme_license"
        case featureSwitches = "feature_switches"
    }

    private struct ColorThemeLicenseEntry: Codable {
        let enabled: Bool?
        let licenseDays: Int?

        private enum CodingKeys: String, CodingKey {
            case enabled
            case licenseDays = "license_days"
        }

        var policy: ColorThemeLicensePolicy {
            return .init(
                isEnabled: self.enabled,
                licenseDays: self.licenseDays.flatMap { $0 > 0 ? $0 : nil }
            )
        }
    }

    private struct FeatureSwitchEntry: Codable {
        let enabled: Bool
        let minAppVersion: String?
        let rolloutPercentage: Int?

        private enum CodingKeys: String, CodingKey {
            case enabled
            case minAppVersion = "min_app_version"
            case rolloutPercentage = "rollout_percentage"
        }
    }

    let policy: AppPolicy

    init(policy: AppPolicy) {
        self.policy = policy
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let license = try container.decodeIfPresent(ColorThemeLicenseEntry.self, forKey: .colorThemeLicense)
        let switches = try container.decodeIfPresent(
            [String: FeatureSwitchEntry].self, forKey: .featureSwitches
        )
        self.policy = AppPolicy(
            colorThemeLicense: license?.policy,
            featureSwitches: (switches ?? [:]).mapValues { entry in
                FeatureSwitch(
                    isEnabled: entry.enabled,
                    minAppVersion: entry.minAppVersion,
                    rolloutPercentage: entry.rolloutPercentage.map { min(max($0, 0), 100) }
                )
            }
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(
            self.policy.colorThemeLicense
                .map { ColorThemeLicenseEntry(enabled: $0.isEnabled, licenseDays: $0.licenseDays) },
            forKey: .colorThemeLicense
        )
        try container.encode(
            self.policy.featureSwitches
                .mapValues {
                    FeatureSwitchEntry(
                        enabled: $0.isEnabled,
                        minAppVersion: $0.minAppVersion,
                        rolloutPercentage: $0.rolloutPercentage
                    )
                },
            forKey: .featureSwitches
        )
    }
}
