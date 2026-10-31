//
//  PaidFeatureGateUsecaseImple.swift
//  BillingDomain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import BillingDomainInterface

public final class PaidFeatureGateUsecaseImple: PaidFeatureGateUsecase {

    private enum Constant {
        static let secondsPerDay: TimeInterval = 24 * 3600
    }

    private let planSource: any BillingUserPlanSource
    private let licenseRepository: any ColorThemeLicenseRepository
    private let widgetStyleLicenseRepository: any WidgetStyleLicenseRepository
    private let policyRepository: any AppPolicyRepository
    private let defaultPolicy: AppPolicy

    public init(
        planSource: any BillingUserPlanSource,
        licenseRepository: any ColorThemeLicenseRepository,
        widgetStyleLicenseRepository: any WidgetStyleLicenseRepository,
        policyRepository: any AppPolicyRepository,
        defaultPolicy: AppPolicy
    ) {
        self.planSource = planSource
        self.licenseRepository = licenseRepository
        self.widgetStyleLicenseRepository = widgetStyleLicenseRepository
        self.policyRepository = policyRepository
        self.defaultPolicy = defaultPolicy
    }
}


// MARK: - 검사

extension PaidFeatureGateUsecaseImple {

    private typealias LicenseTerms = (isEnabled: Bool?, licenseDays: Int?)

    public func check(_ feature: PaidFeature, at now: Date) throws {
        guard self.isFreeToUse(feature) == false,
              let licenseDays = self.enforcedLicenseDays(of: feature),
              self.isLicenseValid(of: feature, licenseDays: licenseDays, at: now) == false
        else { return }
        throw PaidFeatureGateFailReason(feature: feature, licenseDays: licenseDays)
    }

    private func isFreeToUse(_ feature: PaidFeature) -> Bool {
        let plan = self.planSource.latestUserPlan()
        switch feature {
        case .colorTheme(isCustom: true):
            return plan?.isPaid != false
        case .colorTheme(isCustom: false):
            return true
        case .customizeWidget:
            let isPaid = plan.map { $0.isPaid } ?? false
            return isPaid != false
        }
    }

    private func enforcedLicenseDays(of feature: PaidFeature) -> Int? {
        let (received, fallback) = self.licenseTerms(of: feature)
        guard (received?.isEnabled ?? fallback?.isEnabled) == true,
              let licenseDays = received?.licenseDays ?? fallback?.licenseDays,
              licenseDays > 0
        else { return nil }
        return licenseDays
    }

    private func licenseTerms(of feature: PaidFeature) -> (received: LicenseTerms?, fallback: LicenseTerms?) {
        let received = self.policyRepository.loadPolicy()
        switch feature {
        case .colorTheme:
            return (
                received?.colorThemeLicense.map { (isEnabled: $0.isEnabled, licenseDays: $0.licenseDays) },
                self.defaultPolicy.colorThemeLicense.map { (isEnabled: $0.isEnabled, licenseDays: $0.licenseDays) }
            )
        case .customizeWidget:
            return (
                received?.widgetStyleLicense.map { (isEnabled: $0.isEnabled, licenseDays: $0.licenseDays) },
                self.defaultPolicy.widgetStyleLicense.map { (isEnabled: $0.isEnabled, licenseDays: $0.licenseDays) }
            )
        }
    }

    private func isLicenseValid(of feature: PaidFeature, licenseDays: Int, at now: Date) -> Bool {
        let grantedAt: Date? = switch feature {
        case .colorTheme: self.licenseRepository.loadLicense()?.grantedAt
        case .customizeWidget: self.widgetStyleLicenseRepository.loadLicense()?.grantedAt
        }
        guard let grantedAt else { return false }
        let expiresAt = grantedAt.addingTimeInterval(TimeInterval(licenseDays) * Constant.secondsPerDay)
        return grantedAt <= now && now < expiresAt
    }
}


// MARK: - 사용권 기록

extension PaidFeatureGateUsecaseImple {

    public func grantLicense(for feature: PaidFeature, at now: Date) {
        switch feature {
        case .colorTheme:
            self.licenseRepository.updateLicense(.init(grantedAt: now))
        case .customizeWidget:
            self.widgetStyleLicenseRepository.updateLicense(.init(grantedAt: now))
        }
    }
}
