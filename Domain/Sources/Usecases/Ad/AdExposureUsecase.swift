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

    func shouldPreloadFullScreenAds() -> Bool

    func canExposeFullScreenAd(at now: Date) -> Bool

    func recordFullScreenAdExposed(at now: Date)

    func recordEventSavedForFullScreenAd()

    func isFullScreenAdTurnAfterEventSave() -> Bool

    func canRequestTrackingAuthorization() async -> Bool

    func recordTrackingGuideShown()
}


public final class AdExposureUsecaseImple: AdExposureUsecase, Sendable {

    private enum Constant {
        static let fullScreenAdDailyLimit: Int = 3
        static let fullScreenAdMinInterval: TimeInterval = 30 * 60
        static let eventSaveCountPerFullScreenAd: Int = 2
    }

    private let adAvailability: any MobileAdAvailability
    private let billingUsecase: any BillingUsecase
    private let adRepository: any AdRepository
    private let coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository
    private let userEventExistenceRepository: any UserEventExistenceRepository
    private let calendar: Calendar

    public init(
        adAvailability: any MobileAdAvailability,
        billingUsecase: any BillingUsecase,
        adRepository: any AdRepository,
        coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository,
        userEventExistenceRepository: any UserEventExistenceRepository,
        calendar: Calendar = .current
    ) {
        self.adAvailability = adAvailability
        self.billingUsecase = billingUsecase
        self.adRepository = adRepository
        self.coldLaunchHistoryRepository = coldLaunchHistoryRepository
        self.userEventExistenceRepository = userEventExistenceRepository
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

    public func canExposeFullScreenAd(at now: Date) -> Bool {
        guard self.billingUsecase.latestUserPlan()?.planId == .free,
              self.isPastInstallDay(at: now)
        else { return false }
        guard let record = self.adRepository.loadFullScreenAdExposureRecord() else { return true }
        return self.countOfToday(record, at: now) < Constant.fullScreenAdDailyLimit
            && now.timeIntervalSince(record.lastExposeDate) >= Constant.fullScreenAdMinInterval
    }

    public func recordFullScreenAdExposed(at now: Date) {
        let countOfToday = self.adRepository.loadFullScreenAdExposureRecord()
            .map { self.countOfToday($0, at: now) } ?? 0
        self.adRepository.updateFullScreenAdExposureRecord(
            .init(lastExposeDate: now, countOfDay: countOfToday + 1)
        )
    }

    public func recordEventSavedForFullScreenAd() {
        let count = self.adRepository.loadEventSavedCountForFullScreenAd()
        self.adRepository.updateEventSavedCountForFullScreenAd(count + 1)
    }

    public func isFullScreenAdTurnAfterEventSave() -> Bool {
        let count = self.adRepository.loadEventSavedCountForFullScreenAd()
        return count > 0 && count % Constant.eventSaveCountPerFullScreenAd == 0
    }

    private func isPastInstallDay(at now: Date) -> Bool {
        return self.coldLaunchHistoryRepository.loadColdLaunchHistory()
            .elapsedDaysFromFirstLaunch(to: now, self.calendar) >= 1
    }

    private func countOfToday(_ record: FullScreenAdExposureRecord, at now: Date) -> Int {
        return self.calendar.isDate(record.lastExposeDate, inSameDayAs: now) ? record.countOfDay : 0
    }
}


// MARK: - tracking authorization

extension AdExposureUsecaseImple {

    public func canRequestTrackingAuthorization() async -> Bool {
        guard self.adAvailability.isTrackingAuthorizationDetermined == false,
              self.adRepository.loadHasShownTrackingGuide() == false
        else { return false }
        return (try? await self.userEventExistenceRepository.fetchHasAnyEvent()) ?? false
    }

    public func recordTrackingGuideShown() {
        self.adRepository.markTrackingGuideShown()
    }
}
