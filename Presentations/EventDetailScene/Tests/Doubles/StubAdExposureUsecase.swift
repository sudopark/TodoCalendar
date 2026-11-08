//
//  StubAdExposureUsecase.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 11/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class StubAdExposureUsecase: AdExposureUsecase, @unchecked Sendable {

    private let isFullScreenAdTurn: Bool

    init(isFullScreenAdTurn: Bool = false) {
        self.isFullScreenAdTurn = isFullScreenAdTurn
    }

    var isBannerAdAllowed: AnyPublisher<Bool, Never> {
        return Just(false).eraseToAnyPublisher()
    }

    func shouldPreloadFullScreenAds() -> Bool { false }

    func canExposeFullScreenAd(at now: Date) -> Bool { false }

    func recordFullScreenAdExposed(at now: Date) { }

    var didRecordEventSaved: Bool?
    func recordEventSavedForFullScreenAd() {
        self.didRecordEventSaved = true
    }

    var didCheckTurnAfterRecordSaved: Bool?
    func isFullScreenAdTurnAfterEventSave() -> Bool {
        self.didCheckTurnAfterRecordSaved = self.didRecordEventSaved ?? false
        return self.isFullScreenAdTurn
    }

    func canRequestTrackingAuthorization() async -> Bool { false }

    func recordTrackingGuideShown() { }
}
