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

    func canCreateCustomWidgetStyleWithoutAd(at now: Date) -> Bool
    func canRenderCustomWidgetStyle(at now: Date) -> Bool
    func grantCustomWidgetStyleLicense(at now: Date)
}


public final class PaidFeatureGateUsecaseImple: PaidFeatureGateUsecase, Sendable {

    private enum Constant {
        static let secondsPerDay: TimeInterval = 24 * 3600
    }

    private let billingUsecase: any BillingUsecase
    private let licenseRepository: any ColorThemeLicenseRepository
    private let widgetStyleLicenseRepository: any WidgetStyleLicenseRepository
    private let policyRepository: any AppPolicyRepository
    private let defaultPolicy: AppPolicy
    private let freeThemeKeys: [ColorSetKeys] = [.systemTheme, .defaultLight, .defaultDark]

    public init(
        billingUsecase: any BillingUsecase,
        licenseRepository: any ColorThemeLicenseRepository,
        widgetStyleLicenseRepository: any WidgetStyleLicenseRepository,
        policyRepository: any AppPolicyRepository,
        defaultPolicy: AppPolicy
    ) {
        self.billingUsecase = billingUsecase
        self.licenseRepository = licenseRepository
        self.widgetStyleLicenseRepository = widgetStyleLicenseRepository
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


// MARK: - 위젯 커스텀 스타일

extension PaidFeatureGateUsecaseImple {

    public func canCreateCustomWidgetStyleWithoutAd(at now: Date) -> Bool {
        guard let plan = self.billingUsecase.latestUserPlan()
        else { return self.isWidgetStyleLicenseGateDisabled() }
        return self.canUseCustomWidgetStyle(isPaid: plan.isPaid, at: now)
    }

    public func canRenderCustomWidgetStyle(at now: Date) -> Bool {
        guard let plan = self.billingUsecase.latestUserPlan() else { return true }
        return self.canUseCustomWidgetStyle(isPaid: plan.isPaid, at: now)
    }

    private func canUseCustomWidgetStyle(isPaid: Bool?, at now: Date) -> Bool {
        guard isPaid == false,
              let policy = self.resolveWidgetStyleLicensePolicy(),
              policy.isEnabled,
              policy.licenseDays > 0
        else { return true }
        return self.isWidgetStyleLicenseValid(licenseDays: policy.licenseDays, at: now)
    }

    private func isWidgetStyleLicenseGateDisabled() -> Bool {
        guard let policy = self.resolveWidgetStyleLicensePolicy() else { return true }
        return policy.isEnabled == false || policy.licenseDays <= 0
    }

    private func resolveWidgetStyleLicensePolicy() -> (isEnabled: Bool, licenseDays: Int)? {
        let received = self.policyRepository.loadPolicy()?.widgetStyleLicense
        let fallback = self.defaultPolicy.widgetStyleLicense
        guard let isEnabled = received?.isEnabled ?? fallback?.isEnabled,
              let licenseDays = received?.licenseDays ?? fallback?.licenseDays
        else { return nil }
        return (isEnabled, licenseDays)
    }

    private func isWidgetStyleLicenseValid(licenseDays: Int, at now: Date) -> Bool {
        guard let license = self.widgetStyleLicenseRepository.loadLicense() else { return false }
        let expiresAt = license.grantedAt
            .addingTimeInterval(TimeInterval(licenseDays) * Constant.secondsPerDay)
        return license.grantedAt <= now && now < expiresAt
    }
}


// MARK: - 위젯 커스텀 스타일 보상 반영

extension PaidFeatureGateUsecaseImple {

    public func grantCustomWidgetStyleLicense(at now: Date) {
        self.widgetStyleLicenseRepository.updateLicense(.init(grantedAt: now))
    }
}
