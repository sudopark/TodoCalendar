//
//  AppUsageRecordLocalRepositoryImple.swift
//  SupportDomain
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions
import StorageInfraInterface
import SupportDomainInterface


public final class AppUsageRecordLocalRepositoryImple: AppUsageRecordRepository {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private enum Constant {
        static let savedNewEventCountKey: String = "app_usage_saved_new_event_count"
        static let lastReviewRequestedAppVersionKey: String = "app_usage_last_review_requested_app_version"
    }
}

extension AppUsageRecordLocalRepositoryImple {

    public func loadSavedNewEventCount() -> Int {
        return self.environmentStorage.load(Constant.savedNewEventCountKey) ?? 0
    }

    public func increaseSavedNewEventCount() {
        let count = self.loadSavedNewEventCount()
        self.environmentStorage.update(Constant.savedNewEventCountKey, count + 1)
        self.environmentStorage.synchronize()
    }

    public func loadLastReviewRequestedAppVersion() -> String? {
        return self.environmentStorage.load(Constant.lastReviewRequestedAppVersionKey)
    }

    public func saveLastReviewRequestedAppVersion(_ version: String) {
        self.environmentStorage.update(Constant.lastReviewRequestedAppVersionKey, version)
        self.environmentStorage.synchronize()
    }
}
