//
//  AdLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class AdLocalRepositoryImple: AdRepository, Sendable {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private var exposureRecordKey: String { EnvironmentKeys.fullScreenAdExposureRecord.rawValue }
    private var eventSavedCountKey: String { EnvironmentKeys.fullScreenAdEventSavedCount.rawValue }
    private var trackingGuideShownKey: String { EnvironmentKeys.trackingGuideShown.rawValue }
}

extension AdLocalRepositoryImple {

    public func loadFullScreenAdExposureRecord() -> FullScreenAdExposureRecord? {
        let mapper: FullScreenAdExposureRecordMapper? = self.environmentStorage.load(
            self.exposureRecordKey
        )
        return mapper?.record
    }

    public func updateFullScreenAdExposureRecord(_ record: FullScreenAdExposureRecord) {
        self.environmentStorage.update(
            self.exposureRecordKey, FullScreenAdExposureRecordMapper(record: record)
        )
    }

    public func loadEventSavedCountForFullScreenAd() -> Int {
        return self.environmentStorage.load(self.eventSavedCountKey) ?? 0
    }

    public func updateEventSavedCountForFullScreenAd(_ count: Int) {
        self.environmentStorage.update(self.eventSavedCountKey, count)
        self.environmentStorage.synchronize()
    }

    public func loadHasShownTrackingGuide() -> Bool {
        return self.environmentStorage.load(self.trackingGuideShownKey) ?? false
    }

    public func markTrackingGuideShown() {
        self.environmentStorage.update(self.trackingGuideShownKey, true)
        self.environmentStorage.synchronize()
    }
}
