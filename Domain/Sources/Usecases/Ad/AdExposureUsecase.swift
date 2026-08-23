//
//  AdExposureUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol AdExposureUsecase: Sendable {

    var isBannerAdAllowed: AnyPublisher<Bool, Never> { get }

    func canExposeFullScreenAd(
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool,
        at now: Date
    ) -> Bool

    func recordFullScreenAdExposed(scope: FullScreenAdExposureRecord.Scope, at now: Date)
}


public final class AdExposureUsecaseImple: AdExposureUsecase, Sendable {

    private enum Constant {
        static let appLaunchColdLaunchCountThreshold: Int = 10
        static let appLaunchElapsedDaysThreshold: Int = 7
    }

    private let adAvailability: any MobileAdAvailability
    private let billingUsecase: any BillingUsecase
    private let adRepository: any AdRepository
    private let coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository
    private let calendar: Calendar

    public init(
        adAvailability: any MobileAdAvailability,
        billingUsecase: any BillingUsecase,
        adRepository: any AdRepository,
        coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository,
        calendar: Calendar = .current
    ) {
        self.adAvailability = adAvailability
        self.billingUsecase = billingUsecase
        self.adRepository = adRepository
        self.coldLaunchHistoryRepository = coldLaunchHistoryRepository
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

    public func canExposeFullScreenAd(
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool,
        at now: Date
    ) -> Bool {
        guard self.billingUsecase.latestUserPlan()?.planId == .free,
              self.isExposedToday(scope, at: now) == false
        else { return false }
        guard isFromAppLaunch else { return true }
        return self.satisfiesAppLaunchConditions(at: now)
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
}
