//
//  AdExposureUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineSchedulers


public protocol AdExposureUsecase: Sendable {

    var isBannerAdAllowed: AnyPublisher<Bool, Never> { get }

    var isMainBannerAdAllowed: AnyPublisher<Bool, Never> { get }

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
    }

    private let adAvailability: any MobileAdAvailability
    private let billingUsecase: any BillingUsecase
    private let adRepository: any AdRepository
    private let coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository
    private let userEventExistenceRepository: any UserEventExistenceRepository
    private let policyRepository: any AppPolicyRepository
    private let defaultPolicy: AppPolicy
    private let calendar: Calendar
    private let scheduler: AnySchedulerOf<DispatchQueue>
    private let mainBannerDelayOfThisLaunch: TimeInterval?

    public init(
        adAvailability: any MobileAdAvailability,
        billingUsecase: any BillingUsecase,
        adRepository: any AdRepository,
        coldLaunchHistoryRepository: any AppColdLaunchHistoryRepository,
        userEventExistenceRepository: any UserEventExistenceRepository,
        policyRepository: any AppPolicyRepository,
        defaultPolicy: AppPolicy,
        calendar: Calendar = .current,
        scheduler: AnySchedulerOf<DispatchQueue> = .main,
        randomUnit: @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.adAvailability = adAvailability
        self.billingUsecase = billingUsecase
        self.adRepository = adRepository
        self.coldLaunchHistoryRepository = coldLaunchHistoryRepository
        self.userEventExistenceRepository = userEventExistenceRepository
        self.policyRepository = policyRepository
        self.defaultPolicy = defaultPolicy
        self.calendar = calendar
        self.scheduler = scheduler
        self.mainBannerDelayOfThisLaunch = (defaultPolicy.mainBannerExposure ?? .init())
            .overriding(with: policyRepository.loadPolicy()?.mainBannerExposure)
            .drawDelay(randomUnit)
    }
}


private extension MainBannerExposurePolicy {

    func overriding(with received: MainBannerExposurePolicy?) -> MainBannerExposurePolicy {
        return .init(
            exposurePercentage: received?.exposurePercentage ?? self.exposurePercentage,
            minDelaySeconds: received?.minDelaySeconds ?? self.minDelaySeconds,
            maxDelaySeconds: received?.maxDelaySeconds ?? self.maxDelaySeconds
        )
    }

    func drawDelay(_ randomUnit: () -> Double) -> TimeInterval? {
        guard randomUnit() * 100 < Double(self.exposurePercentage ?? 0) else { return nil }
        let minDelay = TimeInterval(self.minDelaySeconds ?? 0)
        let maxDelay = max(TimeInterval(self.maxDelaySeconds ?? 0), minDelay)
        return minDelay + randomUnit() * (maxDelay - minDelay)
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

    public var isMainBannerAdAllowed: AnyPublisher<Bool, Never> {
        guard let delay = self.mainBannerDelayOfThisLaunch,
              self.isPastInstallDay(at: Date())
        else { return Just(false).eraseToAnyPublisher() }

        let isDelayPassed = Just(true)
            .delay(for: .seconds(delay), scheduler: self.scheduler)
            .prepend(false)
        return Publishers.CombineLatest(self.isBannerAdAllowed, isDelayPassed)
            .map { isBannerAllowed, isDelayPassed in isBannerAllowed && isDelayPassed }
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
        let interval = self.policyRepository.loadPolicy()?.fullScreenAdEventSaveInterval
            ?? self.defaultPolicy.fullScreenAdEventSaveInterval
            ?? 0
        return interval > 0 && count > 0 && count % interval == 0
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
