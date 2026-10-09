//
//  GoogleMobileAdsServiceImple.swift
//  AdService
//
//  Created by sudo.park on 8/16/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Combine
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform
import Domain
import Extensions


public final class GoogleMobileAdsServiceImple: MobileAdService, @unchecked Sendable {

    private enum Constant {
        static let fullScreenAdExpirationInterval: TimeInterval = 60 * 60
        static let rewardedAdExpirationInterval: TimeInterval = 60 * 60
        static let rewardedAdPollingInterval: Duration = .milliseconds(100)
    }

    private let testDeviceIdentifiers: [String]
    private let fullScreenAdUnitId: String
    private let rewardedAdUnitId: String

    public init(
        testDeviceIdentifiers: [String],
        fullScreenAdUnitId: String,
        rewardedAdUnitId: String
    ) {
        self.testDeviceIdentifiers = testDeviceIdentifiers
        self.fullScreenAdUnitId = fullScreenAdUnitId
        self.rewardedAdUnitId = rewardedAdUnitId
    }

    private struct Subject {
        let isStart = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()

    private let lock = NSLock()
    private var loadedFullScreenAd: InterstitialAd?
    private var loadedFullScreenAdAt: Date?
    private var isLoadingFullScreenAd: Bool = false
    private var loadedRewardedAd: RewardedAd?
    private var loadedRewardedAdAt: Date?
    private var isLoadingRewardedAd: Bool = false
    @MainActor private var applicationActiveObserving: AnyCancellable?
}


// MARK: - prepare

extension GoogleMobileAdsServiceImple {
    
    public func start() {
        
        Task { [weak self] in
            #if DEBUG
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = self?.testDeviceIdentifiers
            #endif
            _ = await MobileAds.shared.start()
            self?.subject.isStart.send(true)
        }
    }

    public func presentConsentFormAndTrackingPromptIfNeeded(from viewController: UIViewController) async {
        
        await self.updateConsentInfo()
        
        _ = await Task { @MainActor [weak self] in
            await self?.presentConsentFormIfRequired(from: viewController)
            await self?.requestTrackingAuthorization()
        }.value
    }
}


// MARK: - UMP consent

extension GoogleMobileAdsServiceImple {

    private func updateConsentInfo() async {
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(
                with: RequestParameters()
            ) { error in
                if let error {
                    logger.log(level: .error, "UMP consent info update failed: \(error)")
                }
                continuation.resume()
            }
        }
    }

    @MainActor
    private func presentConsentFormIfRequired(from viewController: UIViewController) async {
        await withCheckedContinuation { continuation in
            ConsentForm.loadAndPresentIfRequired(from: viewController) { error in
                if let error {
                    logger.log(level: .error, "UMP consent form present failed: \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    @MainActor
    public func isPrivacyOptionsRequired() -> Bool {
        return ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
    
    @MainActor
    public func showPrivacyOptionsForm(from viewController: UIViewController) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            ConsentForm.presentPrivacyOptionsForm(from: viewController) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}


// MARK: - ATT

extension GoogleMobileAdsServiceImple {
    
    @MainActor
    private func requestTrackingAuthorization() async {
        await self.waitUntilApplicationIsActive()
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
    
    // 앱이 active 가 아니면 프롬프트 없이 즉시 반환돼 요청 기회를 한 번 소모한다
    @MainActor
    private func waitUntilApplicationIsActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        await withCheckedContinuation { continuation in
            self.applicationActiveObserving = NotificationCenter.default
                .publisher(for: UIApplication.didBecomeActiveNotification)
                .first()
                .sink { _ in continuation.resume() }
        }
        self.applicationActiveObserving = nil
    }
}


// MARK: - full screen ad preload

extension GoogleMobileAdsServiceImple {

    public func preloadFullScreenAd() async {
        guard self.isStartedNow else { return }
        let shouldLoad = self.lock.withLock {
            guard self.isLoadingFullScreenAd == false,
                  self.hasValidLoadedFullScreenAd == false
            else { return false }
            self.isLoadingFullScreenAd = true
            return true
        }
        guard shouldLoad else { return }

        do {
            let ad = try await InterstitialAd.load(
                with: self.fullScreenAdUnitId, request: Request()
            )
            self.lock.withLock {
                self.loadedFullScreenAd = ad
                self.loadedFullScreenAdAt = Date()
                self.isLoadingFullScreenAd = false
            }
        } catch {
            logger.log(level: .error, "interstitial ad preload failed: \(error)")
            self.lock.withLock { self.isLoadingFullScreenAd = false }
        }
    }

    public func takePreloadedFullScreenAd() -> InterstitialAd? {
        let result: InterstitialAd? = self.lock.withLock {
            guard let loadedAd = self.loadedFullScreenAd else { return nil }
            defer {
                self.loadedFullScreenAd = nil
                self.loadedFullScreenAdAt = nil
            }
            return self.hasValidLoadedFullScreenAd ? loadedAd : nil
        }
        guard let result else {
            Task { [weak self] in
                await self?.preloadFullScreenAd()
            }
            return nil
        }
        return result
    }

    private var hasValidLoadedFullScreenAd: Bool {
        guard let loadedAt = self.loadedFullScreenAdAt else { return false }
        return Date().timeIntervalSince(loadedAt) < Constant.fullScreenAdExpirationInterval
    }
}


// MARK: - rewarded ad preload

extension GoogleMobileAdsServiceImple {

    public func preloadRewardedAd() async {
        guard self.isStartedNow else { return }
        let shouldLoad = self.lock.withLock {
            guard self.isLoadingRewardedAd == false,
                  self.hasValidLoadedRewardedAd == false
            else { return false }
            self.isLoadingRewardedAd = true
            return true
        }
        guard shouldLoad else { return }

        do {
            let ad = try await RewardedAd.load(
                with: self.rewardedAdUnitId, request: Request()
            )
            self.lock.withLock {
                self.loadedRewardedAd = ad
                self.loadedRewardedAdAt = Date()
                self.isLoadingRewardedAd = false
            }
        } catch {
            logger.log(level: .error, "rewarded ad preload failed: \(error)")
            self.lock.withLock { self.isLoadingRewardedAd = false }
        }
    }

    public func takeRewardedAd(waitingUpTo timeout: TimeInterval) async -> RewardedAd? {
        guard self.isStartedNow else { return nil }
        let deadline: Date = Date().addingTimeInterval(timeout)

        // 로드는 호출자 시한과 무관하게 끝까지 돌아 캐시를 채운다
        Task { [weak self] in
            await self?.preloadRewardedAd()
        }

        while true {
            if let ad = self.takeValidLoadedRewardedAd() {
                Task { [weak self] in
                    await self?.preloadRewardedAd()
                }
                return ad
            }
            guard Date() < deadline else { return nil }
            try? await Task.sleep(for: Constant.rewardedAdPollingInterval)
            guard Task.isCancelled == false else { return nil }
        }
    }

    private func takeValidLoadedRewardedAd() -> RewardedAd? {
        return self.lock.withLock {
            guard let loadedAd = self.loadedRewardedAd else { return nil }
            defer {
                self.loadedRewardedAd = nil
                self.loadedRewardedAdAt = nil
            }
            return self.hasValidLoadedRewardedAd ? loadedAd : nil
        }
    }

    private var hasValidLoadedRewardedAd: Bool {
        guard let loadedAt = self.loadedRewardedAdAt else { return false }
        return Date().timeIntervalSince(loadedAt) < Constant.rewardedAdExpirationInterval
    }
}


// MARK: - MobileAdAvailability

extension GoogleMobileAdsServiceImple: MobileAdAvailability {

    public var isStarted: AnyPublisher<Bool, Never> {
        return self.subject.isStart
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var isStartedNow: Bool { self.subject.isStart.value }
}
