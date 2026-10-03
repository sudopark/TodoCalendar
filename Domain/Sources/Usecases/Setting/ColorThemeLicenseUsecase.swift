//
//  ColorThemeLicenseUsecase.swift
//  Domain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol ColorThemeLicenseUsecase: Sendable {

    func canApplyWithoutAd(_ key: ColorSetKeys, at now: Date) -> Bool
    func grantLicense(at now: Date)
}


public final class ColorThemeLicenseUsecaseImple: ColorThemeLicenseUsecase, Sendable {

    private enum Constant {
        static let secondsPerDay: TimeInterval = 24 * 3600
    }

    private let billingUsecase: any BillingUsecase
    private let licenseRepository: any ColorThemeLicenseRepository
    private let policyRepository: any AppPolicyRepository
    private let freeThemeKeys: [ColorSetKeys] = [.systemTheme, .defaultLight, .defaultDark]

    public init(
        billingUsecase: any BillingUsecase,
        licenseRepository: any ColorThemeLicenseRepository,
        policyRepository: any AppPolicyRepository
    ) {
        self.billingUsecase = billingUsecase
        self.licenseRepository = licenseRepository
        self.policyRepository = policyRepository
    }
}


// MARK: - 판정

extension ColorThemeLicenseUsecaseImple {

    public func canApplyWithoutAd(_ key: ColorSetKeys, at now: Date) -> Bool {
        guard self.freeThemeKeys.contains(key) == false,
              self.billingUsecase.latestUserPlan()?.isPaid == false,
              let policy = self.policyRepository.loadPolicy()?.colorThemeLicense
        else { return true }
        return self.isLicenseValid(policy, at: now)
    }

    private func isLicenseValid(_ policy: ColorThemeLicensePolicy, at now: Date) -> Bool {
        guard let license = self.licenseRepository.loadLicense() else { return false }
        let expiresAt = license.grantedAt
            .addingTimeInterval(TimeInterval(policy.licenseDays) * Constant.secondsPerDay)
        return license.grantedAt <= now && now < expiresAt
    }
}


// MARK: - 보상 반영

extension ColorThemeLicenseUsecaseImple {

    public func grantLicense(at now: Date) {
        self.licenseRepository.updateLicense(.init(grantedAt: now))
    }
}
