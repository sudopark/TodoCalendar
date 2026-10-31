//
//  AppleCalendarUsecase.swift
//  ExternalCalendarDomainInterface
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - AppleCalendarViewAppearanceStore

public protocol AppleCalendarViewAppearanceStore: Sendable {
    func applyCalendarTags(_ tags: [AppleCalendar.Tag])
    func clearCalendarTags()
}


// MARK: - AppleCalendarUsecase

public protocol AppleCalendarUsecase: Sendable {

    func prepare()
    func refreshCalendarTags()
    func refreshEvents(in period: Range<TimeInterval>)

    var calendarTags: AnyPublisher<[AppleCalendar.Tag], Never> { get }
    func events(in period: Range<TimeInterval>) -> AnyPublisher<[AppleCalendar.Event], Never>
    func eventOrigin(id: String) -> AnyPublisher<AppleCalendar.EventOrigin?, Never>

    /// nil = 아직 판정 불가 (소비측이 판단을 미룬다)
    func isCalendarWritable(_ calendarId: String) -> AnyPublisher<Bool?, Never>

    func updateEvent(
        _ eventId: String,
        params: AppleCalendar.EventEditParams,
        scope: AppleCalendar.EventEditScope
    ) async throws -> AppleCalendar.EventOrigin

    func removeEvent(
        _ eventId: String,
        scope: AppleCalendar.EventEditScope
    ) async throws
}
