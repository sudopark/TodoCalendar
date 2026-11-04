//
//  AppReviewRequestUsecase.swift
//  Domain
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AppReviewRequestUsecase: Sendable {

    func recordNewEventSaved()
    func canRequestReview() -> Bool
    func markReviewRequested()
}


public final class AppReviewRequestUsecaseImple: AppReviewRequestUsecase, @unchecked Sendable {

    private let repository: any AppUsageRecordRepository
    private let planSource: any BillingUserPlanSource
    private let currentAppVersion: String?

    public init(
        repository: any AppUsageRecordRepository,
        planSource: any BillingUserPlanSource,
        deviceInfoFetchService: any DeviceInfoFetchService
    ) {
        self.repository = repository
        self.planSource = planSource
        self.currentAppVersion = deviceInfoFetchService.fetchAppVersion()
    }

    private enum Constant {
        static let savedNewEventCountThreshold: Int = 5
    }
}


// MARK: - command

extension AppReviewRequestUsecaseImple {

    public func recordNewEventSaved() {
        self.repository.increaseSavedNewEventCount()
    }

    public func markReviewRequested() {
        guard let appVersion = self.currentAppVersion else { return }
        self.repository.saveLastReviewRequestedAppVersion(appVersion)
    }
}


// MARK: - query

extension AppReviewRequestUsecaseImple {

    public func canRequestReview() -> Bool {
        guard let appVersion = self.currentAppVersion else { return false }
        return self.repository.loadLastReviewRequestedAppVersion() != appVersion
            && self.repository.loadSavedNewEventCount() >= Constant.savedNewEventCountThreshold
            && self.isPaidUser() == false
    }

    // 플랜 id 를 모르면 유료로 보고, 플랜을 아직 못 받았으면 무료로 본다 (PaidFeatureGateUsecase 와 같은 해석)
    private func isPaidUser() -> Bool {
        return self.planSource.latestUserPlan().map { $0.isPaid != false } ?? false
    }
}
