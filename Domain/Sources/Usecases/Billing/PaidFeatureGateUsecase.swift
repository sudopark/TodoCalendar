//
//  PaidFeatureGateUsecase.swift
//  Domain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol PaidFeatureGateUsecase: Sendable {

    func canApplyColorThemeWithoutAd(_ key: ColorSetKeys, at now: Date) -> Bool
    func grantColorThemeLicense(at now: Date)
}


public final class PaidFeatureGateUsecaseImple: PaidFeatureGateUsecase, Sendable {

    private enum Constant {
        static let secondsPerDay: TimeInterval = 24 * 3600
    }

    private let billingUsecase: any BillingUsecase
    private let licenseRepository: any ColorThemeLicenseRepository
    private let policyRepository: any AppPolicyRepository
    private let defaultPolicy: AppPolicy
    private let freeThemeKeys: [ColorSetKeys] = [.systemTheme, .defaultLight, .defaultDark]

    public init(
        billingUsecase: any BillingUsecase,
        licenseRepository: any ColorThemeLicenseRepository,
        policyRepository: any AppPolicyRepository,
        defaultPolicy: AppPolicy
    ) {
        self.billingUsecase = billingUsecase
        self.licenseRepository = licenseRepository
        self.policyRepository = policyRepository
        self.defaultPolicy = defaultPolicy
    }
}


// MARK: - 컬러 테마

extension PaidFeatureGateUsecaseImple {

    public func canApplyColorThemeWithoutAd(_ key: ColorSetKeys, at now: Date) -> Bool {
        guard self.freeThemeKeys.contains(key) == false,
              self.billingUsecase.latestUserPlan()?.isPaid == false,
              let policy = self.resolveColorThemeLicensePolicy(),
              policy.isEnabled,
              policy.licenseDays > 0
        else { return true }
        return self.isColorThemeLicenseValid(licenseDays: policy.licenseDays, at: now)
    }

    private func resolveColorThemeLicensePolicy() -> (isEnabled: Bool, licenseDays: Int)? {
        let received = self.policyRepository.loadPolicy()?.colorThemeLicense
        let fallback = self.defaultPolicy.colorThemeLicense
        guard let isEnabled = received?.isEnabled ?? fallback?.isEnabled,
              let licenseDays = received?.licenseDays ?? fallback?.licenseDays
        else { return nil }
        return (isEnabled, licenseDays)
    }

    private func isColorThemeLicenseValid(licenseDays: Int, at now: Date) -> Bool {
        guard let license = self.licenseRepository.loadLicense() else { return false }
        let expiresAt = license.grantedAt
            .addingTimeInterval(TimeInterval(licenseDays) * Constant.secondsPerDay)
        return license.grantedAt <= now && now < expiresAt
    }
}


// MARK: - 컬러 테마 보상 반영

extension PaidFeatureGateUsecaseImple {

    public func grantColorThemeLicense(at now: Date) {
        self.licenseRepository.updateLicense(.init(grantedAt: now))
    }
}
