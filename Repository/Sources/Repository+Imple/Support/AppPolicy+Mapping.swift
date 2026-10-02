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
        let licenseDays: Int

        private enum CodingKeys: String, CodingKey {
            case licenseDays = "license_days"
        }
    }

    private struct FeatureSwitchEntry: Codable {
        let enabled: Bool
        let minAppVersion: String?

        private enum CodingKeys: String, CodingKey {
            case enabled
            case minAppVersion = "min_app_version"
        }
    }

    let policy: AppPolicy

    init(policy: AppPolicy) {
        self.policy = policy
    }

    init?(contentsOf fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL),
              let mapper = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        self = mapper
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let license = try container.decodeIfPresent(ColorThemeLicenseEntry.self, forKey: .colorThemeLicense)
        let switches = try container.decodeIfPresent(
            [String: FeatureSwitchEntry].self, forKey: .featureSwitches
        )
        self.policy = AppPolicy(
            colorThemeLicense: license
                .flatMap { $0.licenseDays > 0 ? ColorThemeLicensePolicy(licenseDays: $0.licenseDays) : nil },
            featureSwitches: (switches ?? [:])
                .mapValues { FeatureSwitch(isEnabled: $0.enabled, minAppVersion: $0.minAppVersion) }
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(
            self.policy.colorThemeLicense.map { ColorThemeLicenseEntry(licenseDays: $0.licenseDays) },
            forKey: .colorThemeLicense
        )
        try container.encode(
            self.policy.featureSwitches
                .mapValues { FeatureSwitchEntry(enabled: $0.isEnabled, minAppVersion: $0.minAppVersion) },
            forKey: .featureSwitches
        )
    }
}
