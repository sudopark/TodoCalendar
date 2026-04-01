//
//  AppleCalendarRepository.swift
//  Domain
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - AppleCalendarPermissionChecker

/// 권한 확인/요청 — 위젯 등 경량 컨텍스트에서도 사용
public protocol AppleCalendarPermissionChecker: Sendable {
    func requestAccess() async throws -> Bool
    func checkAccessStatus() -> Bool
}


// MARK: - AppleCalendarRepository

public protocol AppleCalendarRepository: Sendable {

    // 캐시 데이터를 먼저 방출 → 이어 EventKit에서 refresh한 데이터 방출 후 완료
    func loadCalendarTags() -> AnyPublisher<[AppleCalendar.Tag], any Error>

    func loadEvents(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[AppleCalendar.Event], any Error>

    func loadEvent(id: String) -> AnyPublisher<AppleCalendar.Event?, Never>

    func resetCache() async throws
}
