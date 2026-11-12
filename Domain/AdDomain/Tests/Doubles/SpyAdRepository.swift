//
//  SpyAdRepository.swift
//  AdDomainTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
@testable import AdDomain
@testable import AdDomainInterface



final class SpyAdRepository: AdRepository, @unchecked Sendable {

    private var record: FullScreenAdExposureRecord?
    private var hasShownTrackingGuide: Bool
    private(set) var didUpdatedExposureRecord: FullScreenAdExposureRecord?
    private var eventSavedCount: Int
    private(set) var didUpdatedEventSavedCount: Int?
    private(set) var didMarkTrackingGuideShown: Bool = false

    init(
        record: FullScreenAdExposureRecord? = nil,
        eventSavedCount: Int = 0,
        hasShownTrackingGuide: Bool = false
    ) {
        self.record = record
        self.eventSavedCount = eventSavedCount
        self.hasShownTrackingGuide = hasShownTrackingGuide
    }

    func loadFullScreenAdExposureRecord() -> FullScreenAdExposureRecord? {
        return self.record
    }

    func updateFullScreenAdExposureRecord(_ record: FullScreenAdExposureRecord) {
        self.didUpdatedExposureRecord = record
        self.record = record
    }

    func loadEventSavedCountForFullScreenAd() -> Int {
        return self.eventSavedCount
    }

    func updateEventSavedCountForFullScreenAd(_ count: Int) {
        self.didUpdatedEventSavedCount = count
        self.eventSavedCount = count
    }

    func loadHasShownTrackingGuide() -> Bool {
        return self.hasShownTrackingGuide
    }

    func markTrackingGuideShown() {
        self.didMarkTrackingGuideShown = true
        self.hasShownTrackingGuide = true
    }
}
