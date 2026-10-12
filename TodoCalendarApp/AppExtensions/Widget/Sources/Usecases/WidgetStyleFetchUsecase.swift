//
//  WidgetStyleFetchUsecase.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


// MARK: - WidgetStyleFetchUsecase

protocol WidgetStyleFetchUsecase: Sendable {

    func fetchStyle(of variant: WidgetVariant, selected style: WidgetStyleId.Style) throws -> WidgetStyle?

    func fetchStyleCandidates(of variant: WidgetVariant) -> [(style: WidgetStyle, isSelectable: Bool)]
}


// MARK: - WidgetStyleFetchUsecaseImple

final class WidgetStyleFetchUsecaseImple: WidgetStyleFetchUsecase, @unchecked Sendable {

    private enum Constant {
        static let secondsPerDay: TimeInterval = 24 * 3600
    }

    private let styleRepository: any WidgetStyleRepository
    private let planRepository: any BillingUserPlanRepository
    private let licenseRepository: any WidgetStyleLicenseRepository
    private let policyRepository: any AppPolicyRepository
    private let defaultPolicy: AppPolicy

    init(
        styleRepository: any WidgetStyleRepository,
        planRepository: any BillingUserPlanRepository,
        licenseRepository: any WidgetStyleLicenseRepository,
        policyRepository: any AppPolicyRepository,
        defaultPolicy: AppPolicy
    ) {
        self.styleRepository = styleRepository
        self.planRepository = planRepository
        self.licenseRepository = licenseRepository
        self.policyRepository = policyRepository
        self.defaultPolicy = defaultPolicy
    }
}


// MARK: - 조회

extension WidgetStyleFetchUsecaseImple {

    /// 고른 커스텀이 지워졌으면 기본 저장분으로 돌아간다
    func fetchStyle(
        of variant: WidgetVariant, selected style: WidgetStyleId.Style
    ) throws -> WidgetStyle? {
        let selected = self.styleRepository.loadStyle(for: .init(variant: variant, style: style))
        let fallback = style == .default
            ? nil
            : self.styleRepository.loadStyle(for: .init(variant: variant, style: .default))
        guard let saved = selected ?? fallback else { return nil }
        if let licenseDays = self.blockedLicenseDays(at: Date()) {
            throw PaidFeatureGateFailReason(feature: .customizeWidget, licenseDays: licenseDays)
        }
        return saved
    }

    /// 후보는 기본 스타일을 맨 앞에 항상 두고, 꾸민 적 없는 기본만 막혀도 고를 수 있다
    func fetchStyleCandidates(
        of variant: WidgetVariant
    ) -> [(style: WidgetStyle, isSelectable: Bool)] {
        let styleVariant = variant.styleVariant
        guard let initialSetting = styleVariant.initialSetting else { return [] }
        let savedStyles = self.styleRepository.loadStyles(of: styleVariant)
        let isCustomizable = self.blockedLicenseDays(at: Date()) == nil
        let savedDefault = savedStyles.first { $0.id.style == .default }
            .map { (style: $0, isSelectable: isCustomizable) }
        let initialDefault = (
            style: WidgetStyle(id: .init(variant: variant, style: .default), name: nil, setting: initialSetting),
            isSelectable: true
        )
        let customStyles = savedStyles
            .filter { $0.id.style != .default }
            .map { (style: $0, isSelectable: isCustomizable) }
        return [savedDefault ?? initialDefault] + customStyles
    }
}


// MARK: - 꾸미기 권한

extension WidgetStyleFetchUsecaseImple {

    /// 플랜을 모르면 무료로 본다 — 광고로 받은 사용권은 그대로 통과시킨다
    private func blockedLicenseDays(at now: Date) -> Int? {
        let isPaid = self.planRepository.fetchPlan().map { $0.isPaid } ?? false
        let received = self.policyRepository.loadPolicy()?.widgetStyleLicense
        let fallback = self.defaultPolicy.widgetStyleLicense
        guard isPaid == false,
              (received?.isEnabled ?? fallback?.isEnabled) == true,
              let licenseDays = received?.licenseDays ?? fallback?.licenseDays,
              licenseDays > 0,
              self.isLicenseValid(licenseDays: licenseDays, at: now) == false
        else { return nil }
        return licenseDays
    }

    private func isLicenseValid(licenseDays: Int, at now: Date) -> Bool {
        guard let grantedAt = self.licenseRepository.loadLicense()?.grantedAt else { return false }
        let expiresAt = grantedAt.addingTimeInterval(TimeInterval(licenseDays) * Constant.secondsPerDay)
        return grantedAt <= now && now < expiresAt
    }
}
