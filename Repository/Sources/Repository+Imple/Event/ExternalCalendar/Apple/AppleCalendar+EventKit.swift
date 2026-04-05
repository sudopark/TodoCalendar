//
//  AppleCalendar+Mapping.swift
//  Repository
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import EventKit
import Domain


// MARK: - AppleCalendarStoreAccessor

/// EKEventStore 추상화 프로토콜 — 테스트 가능성을 위해 분리
public protocol AppleCalendarStoreAccessor: Sendable {
    func requestFullAccessToEvents() async throws -> Bool
    func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus
    func loadCalendarTags() -> [AppleCalendar.Tag]
    func loadEvents(in period: Range<TimeInterval>) -> [AppleCalendar.Event]
    func loadEvent(id: String) -> AppleCalendar.Event?
}


// MARK: - AppleCalendarPermissionCheckerImple

public final class AppleCalendarPermissionCheckerImple: AppleCalendarPermissionChecker, @unchecked Sendable {

    private let storeAccessor: any AppleCalendarStoreAccessor

    public init(storeAccessor: any AppleCalendarStoreAccessor) {
        self.storeAccessor = storeAccessor
    }

    public func requestAccess() async throws -> Bool {
        return try await storeAccessor.requestFullAccessToEvents()
    }

    public func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus {
        return storeAccessor.checkAuthorizationStatus()
    }
}


// MARK: - EKEventStoreWrapper

public final class EKEventStoreWrapper: AppleCalendarStoreAccessor, @unchecked Sendable {

    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func requestFullAccessToEvents() async throws -> Bool {
        return try await store.requestFullAccessToEvents()
    }

    public func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .restricted:    return .restricted
        case .denied:        return .denied
        case .fullAccess:    return .fullAccess
        case .writeOnly:     return .writeOnly
        @unknown default:    return .denied
        }
    }

    public func loadCalendarTags() -> [AppleCalendar.Tag] {
        return store.calendars(for: .event).map { $0.asAppleCalendarTag() }
    }

    public func loadEvents(in period: Range<TimeInterval>) -> [AppleCalendar.Event] {
        let calendars = store.calendars(for: .event)
        let start = Date(timeIntervalSince1970: period.lowerBound)
        let end = Date(timeIntervalSince1970: period.upperBound)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).compactMap { $0.asAppleCalendarEvent() }
    }

    public func loadEvent(id: String) -> AppleCalendar.Event? {
        return store.event(withIdentifier: id)?.asAppleCalendarEvent()
    }
}


// MARK: - EKCalendar → AppleCalendar.Tag

private extension EKCalendar {

    func asAppleCalendarTag() -> AppleCalendar.Tag {
        return AppleCalendar.Tag(
            id: calendarIdentifier,
            name: title,
            colorHex: cgColor?.hexString
        )
    }
}


// MARK: - EKEvent → AppleCalendar.Event

private extension EKEvent {

    func asAppleCalendarEvent() -> AppleCalendar.Event? {
        guard let eventId = eventIdentifier,
              let calendarId = calendar?.calendarIdentifier
        else { return nil }

        let eventTime = isAllDay
            ? makeAllDayEventTime()
            : makePeriodEventTime()

        guard let eventTime else { return nil }

        return AppleCalendar.Event(
            eventId: eventId,
            calendarId: calendarId,
            name: title ?? "",
            eventTime: eventTime,
            location: location
        )
    }

    private func makeAllDayEventTime() -> EventTime? {
        guard let start = startDate, let end = endDate else { return nil }
        let secondsFromGMT = TimeZone.current.secondsFromGMT()
        return .allDay(
            start.timeIntervalSince1970..<end.timeIntervalSince1970,
            secondsFromGMT: Double(secondsFromGMT)
        )
    }

    private func makePeriodEventTime() -> EventTime? {
        guard let start = startDate, let end = endDate else { return nil }
        return .period(start.timeIntervalSince1970..<end.timeIntervalSince1970)
    }
}


// MARK: - CGColor → hex string

private extension CGColor {

    var hexString: String? {
        guard let components = self.components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
