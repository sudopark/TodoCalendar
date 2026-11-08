//
//  SpyAdRepository.swift
//  DomainTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import Domain


final class SpyAdRepository: AdRepository, @unchecked Sendable {

    private var record: FullScreenAdExposureRecord?
    private var hasShownTrackingGuide: Bool
    private(set) var didUpdatedExposureRecord: FullScreenAdExposureRecord?
    private(set) var didMarkTrackingGuideShown: Bool = false

    init(
        record: FullScreenAdExposureRecord? = nil,
        hasShownTrackingGuide: Bool = false
    ) {
        self.record = record
        self.hasShownTrackingGuide = hasShownTrackingGuide
    }

    func loadFullScreenAdExposureRecord() -> FullScreenAdExposureRecord? {
        return self.record
    }

    func updateFullScreenAdExposureRecord(_ record: FullScreenAdExposureRecord) {
        self.didUpdatedExposureRecord = record
        self.record = record
    }

    func loadHasShownTrackingGuide() -> Bool {
        return self.hasShownTrackingGuide
    }

    func markTrackingGuideShown() {
        self.didMarkTrackingGuideShown = true
        self.hasShownTrackingGuide = true
    }
}
