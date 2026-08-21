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
import Extensions


public final class GoogleMobileAdsServiceImple: @unchecked Sendable {
    
    private let testDeviceIdentifiers: [String]
    
    public init(testDeviceIdentifiers: [String]) {
        self.testDeviceIdentifiers = testDeviceIdentifiers
    }
    
    private struct Subject {
        let isStart = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()
    
    @MainActor private var startingTask: Task<Void, Never>?
    @MainActor private var applicationActiveObserving: AnyCancellable?
}


// MARK: - prepare

extension GoogleMobileAdsServiceImple {
    
    @MainActor
    public func prepare(from viewController: UIViewController) async {
        await self.updateConsentInfo()
        await self.presentConsentFormIfRequired(from: viewController)
        await self.requestTrackingAuthorization()
        await self.startIfNeeded()?.value
    }
    
    @MainActor
    private func startIfNeeded() -> Task<Void, Never>? {
        if let task = self.startingTask {
            return task
        }
        guard ConsentInformation.shared.canRequestAds else { return nil }
        
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            #if DEBUG
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = self.testDeviceIdentifiers
            #endif
            _ = await MobileAds.shared.start()
            self.subject.isStart.send(true)
        }
        self.startingTask = task
        return task
    }
}


// MARK: - UMP consent

extension GoogleMobileAdsServiceImple {
    
    @MainActor
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
            // canRequestAds 는 update 호출 직후부터 이전 세션 동의를 반영한다 (UMPConsentInformation.h:76-79)
            _ = self.startIfNeeded()
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


// MARK: - isStarted

extension GoogleMobileAdsServiceImple {
    
    var isStarted: AnyPublisher<Bool, Never> {
        return self.subject.isStart
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
