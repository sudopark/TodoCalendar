//
//  AppUsageRecordRepository.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 동기 API인 이유 — 구현이 UserDefaults 단독이다
public protocol AppUsageRecordRepository: Sendable {

    func loadSavedNewEventCount() -> Int
    func increaseSavedNewEventCount()
    func loadLastReviewRequestedAppVersion() -> String?
    func saveLastReviewRequestedAppVersion(_ version: String)
}
