//
//  AdExposureUsecaseImple.swift
//  AdDomain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import AdDomainInterface
import BillingDomainInterface
import KernelUtils
import SettingDomainInterface

public final class AdExposureUsecaseImple: AdExposureUsecase, Sendable {

    private enum Constant {
        static let appLaunchColdLaunchCountThreshold: Int = 10
        static let appLaunchElapsedDaysThreshold: Int = 7
    }

    private let adAvailability: any MobileAdAvailability
    private let billingUsecase: any BillingUsecase
    private let adRepository: any AdRepository
    private let coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository
    private let paidFeatureGateUsecase: any PaidFeatureGateUsecase
    private let sharedDataStore: SharedDataStore
    private let calendar: Calendar

    public init(
        adAvailability: any MobileAdAvailability,
        billingUsecase: any BillingUsecase,
        adRepository: any AdRepository,
        coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository,
        paidFeatureGateUsecase: any PaidFeatureGateUsecase,
        sharedDataStore: SharedDataStore,
        calendar: Calendar = .current
    ) {
        self.adAvailability = adAvailability
        self.billingUsecase = billingUsecase
        self.adRepository = adRepository
        self.coldLaunchHistoryRepository = coldLaunchHistoryRepository
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
        self.sharedDataStore = sharedDataStore
        self.calendar = calendar
    }
}


// MARK: - banner

extension AdExposureUsecaseImple {

    public var isBannerAdAllowed: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest(
            self.adAvailability.isStarted, self.billingUsecase.currentUserPlan
        )
        .map { isStarted, userPlan in isStarted && userPlan.planId == .free }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}


// MARK: - full screen

extension AdExposureUsecaseImple {

    public func shouldPreloadFullScreenAds() -> Bool {
        guard let planId = self.billingUsecase.latestUserPlan()?.planId else { return true }
        return planId == .free
    }

    public func canExposeFullScreenAd(
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool,
        at now: Date
    ) -> Bool {
        guard self.billingUsecase.latestUserPlan()?.planId == .free,
              self.isExposedToday(scope, at: now) == false
        else { return false }
        guard isFromAppLaunch else { return true }
        return self.isUsingExpiredPaidTheme(at: now) == false
            && self.satisfiesAppLaunchConditions(at: now)
    }

    public func recordFullScreenAdExposed(
        scope: FullScreenAdExposureRecord.Scope, at now: Date
    ) {
        self.adRepository.updateFullScreenAdExposureRecord(
            .init(scope: scope, lastExposeDate: now)
        )
    }

    private func isExposedToday(
        _ scope: FullScreenAdExposureRecord.Scope, at now: Date
    ) -> Bool {
        return self.adRepository.loadFullScreenAdExposureRecords()
            .first { $0.scope == scope }
            .map { self.calendar.isDate($0.lastExposeDate, inSameDayAs: now) } ?? false
    }

    private func satisfiesAppLaunchConditions(at now: Date) -> Bool {
        let history = self.coldLaunchHistoryRepository.loadColdLaunchHistory()
        return history.isFirstLaunchOfDay(self.calendar)
            && history.count >= Constant.appLaunchColdLaunchCountThreshold
            && history.elapsedDaysFromFirstLaunch(to: now, self.calendar) >= Constant.appLaunchElapsedDaysThreshold
    }

    private func isUsingExpiredPaidTheme(at now: Date) -> Bool {
        let setting = self.sharedDataStore.value(
            CalendarAppearanceSettings.self, key: ShareDataKeys.calendarAppearance.rawValue
        )
        guard let colorSetKey = setting?.colorSetKey else { return false }
        do {
            try self.paidFeatureGateUsecase.check(colorSetKey.paidFeature, at: now)
            return false
        } catch {
            return true
        }
    }
}
