//
//  StubAdExposureUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 11/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


public final class StubAdExposureUsecase: AdExposureUsecase, @unchecked Sendable {

    private let isFullScreenAdTurn: Bool

    public init(isFullScreenAdTurn: Bool = false) {
        self.isFullScreenAdTurn = isFullScreenAdTurn
    }

    public var isBannerAdAllowed: AnyPublisher<Bool, Never> {
        return Just(false).eraseToAnyPublisher()
    }

    public var isMainBannerAdAllowed: AnyPublisher<Bool, Never> {
        return Just(false).eraseToAnyPublisher()
    }

    public func shouldPreloadFullScreenAds() -> Bool { false }

    public func canExposeFullScreenAd(at now: Date) -> Bool { false }

    public func recordFullScreenAdExposed(at now: Date) { }

    public var didRecordEventSaved: Bool?
    public func recordEventSavedForFullScreenAd() {
        self.didRecordEventSaved = true
    }

    public var didCheckTurnAfterRecordSaved: Bool?
    public func isFullScreenAdTurnAfterEventSave() -> Bool {
        self.didCheckTurnAfterRecordSaved = self.didRecordEventSaved ?? false
        return self.isFullScreenAdTurn
    }

    public func canRequestTrackingAuthorization() async -> Bool { false }

    public func recordTrackingGuideShown() { }
}
