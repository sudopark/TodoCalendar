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

    private var records: [FullScreenAdExposureRecord]
    private var hasShownTrackingGuide: Bool
    private(set) var didUpdatedExposureRecords: [FullScreenAdExposureRecord] = []
    private(set) var didMarkTrackingGuideShown: Bool = false

    init(
        records: [FullScreenAdExposureRecord] = [],
        hasShownTrackingGuide: Bool = false
    ) {
        self.records = records
        self.hasShownTrackingGuide = hasShownTrackingGuide
    }

    func loadFullScreenAdExposureRecords() -> [FullScreenAdExposureRecord] {
        return self.records
    }

    func updateFullScreenAdExposureRecord(_ record: FullScreenAdExposureRecord) {
        self.didUpdatedExposureRecords.append(record)
        self.records = self.records.filter { $0.scope != record.scope } + [record]
    }

    func loadHasShownTrackingGuide() -> Bool {
        return self.hasShownTrackingGuide
    }

    func markTrackingGuideShown() {
        self.didMarkTrackingGuideShown = true
        self.hasShownTrackingGuide = true
    }
}
