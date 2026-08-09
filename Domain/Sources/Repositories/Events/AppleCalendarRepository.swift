//
//  AppleCalendarRepository.swift
//  Domain
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - AppleCalendarRepository

public protocol AppleCalendarRepository: Sendable {

    func loadCalendarTags() -> AnyPublisher<[AppleCalendar.Tag], any Error>

    func loadEvents(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[AppleCalendar.Event], any Error>

    func loadEventOrigin(id: String) -> AnyPublisher<AppleCalendar.EventOrigin?, Never>

    func resetCache() async throws
}
