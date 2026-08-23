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
    }

    private let testDeviceIdentifiers: [String]
    private let fullScreenAdUnitId: String

    public init(testDeviceIdentifiers: [String], fullScreenAdUnitId: String) {
        self.testDeviceIdentifiers = testDeviceIdentifiers
        self.fullScreenAdUnitId = fullScreenAdUnitId
    }

    private struct Subject {
        let isStart = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()

    private let lock = NSLock()
    private var loadedFullScreenAd: InterstitialAd?
    private var loadedFullScreenAdAt: Date?
    private var isLoadingFullScreenAd: Bool = false
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
                with: self.requestParameters()
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
    
    private func requestParameters() -> RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        let debugSettings = DebugSettings()
        debugSettings.testDeviceIdentifiers = self.testDeviceIdentifiers
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif
        return parameters
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


// MARK: - MobileAdAvailability

extension GoogleMobileAdsServiceImple: MobileAdAvailability {

    public var isStarted: AnyPublisher<Bool, Never> {
        return self.subject.isStart
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var isStartedNow: Bool { self.subject.isStart.value }
}
