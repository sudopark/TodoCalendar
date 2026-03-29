//
//  AppleCalendarRepository.swift
//  Domain
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - AppleCalendarPermissionChecker

/// 권한 확인 전용 — 위젯 등 경량 컨텍스트에서 사용
public protocol AppleCalendarPermissionChecker: Sendable {
    func checkAccessStatus() -> Bool
}


// MARK: - AppleCalendarRepository

public protocol AppleCalendarRepository: AppleCalendarPermissionChecker, Sendable {

    func requestAccess() async throws -> Bool

    func loadCalendarTags() async throws -> [AppleCalendar.Tag]

    func loadEvents(
        in period: Range<TimeInterval>,
        timeZone: TimeZone
    ) async throws -> [AppleCalendar.Event]

    func resetCache() async throws
}
