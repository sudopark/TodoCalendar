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
import Extensions


// MARK: - AppleCalendarStoreAccessor

/// EKEventStore 추상화 프로토콜 — 테스트 가능성을 위해 분리
public protocol AppleCalendarStoreAccessor: Sendable {
    func requestFullAccessToEvents() async throws -> Bool
    func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus
    func loadCalendarTags() -> [AppleCalendar.Tag]
    func loadEventOrigins(in period: Range<TimeInterval>) -> [AppleCalendar.EventOrigin]
    func loadEventOrigin(id: String) -> AppleCalendar.EventOrigin?
    func updateEvent(
        _ eventId: String,
        _ params: AppleCalendar.EventEditParams,
        scope: AppleCalendar.EventEditScope
    ) throws -> AppleCalendar.EventOrigin
    func removeEvent(
        _ eventId: String,
        scope: AppleCalendar.EventEditScope
    ) throws
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

    public func loadEventOrigins(in period: Range<TimeInterval>) -> [AppleCalendar.EventOrigin] {
        let calendars = store.calendars(for: .event)
        let start = Date(timeIntervalSince1970: period.lowerBound)
        let end = Date(timeIntervalSince1970: period.upperBound)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).compactMap { $0.asAppleCalendarEventOrigin() }
    }

    public func loadEventOrigin(id: String) -> AppleCalendar.EventOrigin? {
        return store.event(withIdentifier: id)?.asAppleCalendarEventOrigin()
    }

    public func updateEvent(
        _ eventId: String,
        _ params: AppleCalendar.EventEditParams,
        scope: AppleCalendar.EventEditScope
    ) throws -> AppleCalendar.EventOrigin {
        let event = try self.resolveEvent(eventId)
        try self.assertWritable(event)
        try event.applyEditParams(params)
        try store.save(event, span: scope.asEKSpan, commit: true)
        guard let origin = event.asAppleCalendarEventOrigin() else {
            throw RuntimeError("failed to build apple calendar event origin after update: \(eventId)")
        }
        return origin
    }

    public func removeEvent(
        _ eventId: String,
        scope: AppleCalendar.EventEditScope
    ) throws {
        let event = try self.resolveEvent(eventId)
        try self.assertWritable(event)
        try store.remove(event, span: scope.asEKSpan, commit: true)
    }

    private func resolveEvent(_ eventId: String) throws -> EKEvent {
        let occurrenceId = AppleCalendar.EventOccurrenceId(eventId)
        guard let masterEvent = store.event(withIdentifier: occurrenceId.originalEventId) else {
            throw RuntimeError("apple calendar event not found: \(occurrenceId.originalEventId)")
        }
        guard let occurrenceDate = occurrenceId.occurrenceDate else {
            return masterEvent
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: occurrenceDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw RuntimeError("failed to compute occurrence day range: \(eventId)")
        }
        let predicate = store.predicateForEvents(
            withStart: dayStart, end: dayEnd, calendars: masterEvent.calendar.map { [$0] }
        )
        guard let matched = store.events(matching: predicate).first(where: {
            $0.eventIdentifier == occurrenceId.originalEventId
                && Int($0.occurrenceDate.timeIntervalSince1970) == Int(occurrenceDate.timeIntervalSince1970)
        }) else {
            throw RuntimeError("apple calendar occurrence not found: \(eventId)")
        }
        return matched
    }

    private func assertWritable(_ event: EKEvent) throws {
        guard event.calendar?.allowsContentModifications == true else {
            throw RuntimeError("apple calendar is not writable: \(event.calendar?.calendarIdentifier ?? "unknown")")
        }
    }
}


// MARK: - EKCalendar → AppleCalendar.Tag

private extension EKCalendar {

    func asAppleCalendarTag() -> AppleCalendar.Tag {
        var tag = AppleCalendar.Tag(
            id: calendarIdentifier,
            name: title,
            colorHex: cgColor?.hexString
        )
        tag.isWritable = allowsContentModifications
        return tag
    }
}


// MARK: - AppleCalendar.EventEditScope → EKSpan

private extension AppleCalendar.EventEditScope {

    var asEKSpan: EKSpan {
        switch self {
        case .thisEventOnly: return .thisEvent
        case .thisAndFuture: return .futureEvents
        }
    }
}


// MARK: - EKEvent → AppleCalendar models

private extension EKEvent {

    func asAppleCalendarEvent() -> AppleCalendar.Event? {
        guard let eventId = eventIdentifier,
              let calendarId = calendar?.calendarIdentifier
        else { return nil }

        let eventTime = isAllDay
            ? makeAllDayEventTime()
            : makePeriodEventTime()

        guard let eventTime else { return nil }

        let isRepeating = hasRecurrenceRules
        let compositeId: String = isRepeating
            ? "\(eventId)#occ:\(Int(occurrenceDate.timeIntervalSince1970))"
            : eventId

        var event = AppleCalendar.Event(
            eventId: compositeId,
            originalEventId: eventId,
            calendarId: calendarId,
            name: title ?? "",
            eventTime: eventTime
        )
        event.isRepeating = isRepeating
        event.location = location
        return event
    }

    func asAppleCalendarEventOrigin() -> AppleCalendar.EventOrigin? {
        guard let eventId = eventIdentifier,
              let calendarId = calendar?.calendarIdentifier
        else { return nil }

        let eventTime = isAllDay
            ? makeAllDayEventTime()
            : makePeriodEventTime()

        guard let eventTime else { return nil }

        let isRepeating = hasRecurrenceRules
        let compositeId: String = isRepeating
            ? "\(eventId)#occ:\(Int(occurrenceDate.timeIntervalSince1970))"
            : eventId

        var origin = AppleCalendar.EventOrigin(
            eventId: compositeId,
            originalEventId: eventId,
            calendarId: calendarId,
            name: title ?? "",
            eventTime: eventTime
        )
        origin.isRepeating = isRepeating
        origin.location = location
        origin.recurrenceRules = recurrenceRules?.compactMap { $0.toRRuleString() } ?? []
        origin.attendees = attendees?.compactMap { $0.asAppleCalendarAttendee() } ?? []
        origin.url = url?.absoluteString
        origin.notes = notes
        return origin
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

    func applyEditParams(_ params: AppleCalendar.EventEditParams) throws {
        if let name = params.name {
            title = name
        }
        if let time = params.time {
            applyEventTime(time)
        }
        if let location = params.location {
            self.location = location
        }
        if let url = params.url {
            self.url = try url.asEventURLOrNil()
        }
        if let notes = params.notes {
            self.notes = notes
        }
        if let rules = params.recurrenceRules {
            let converted = rules.compactMap { EKRecurrenceRule(rruleText: $0) }
            // 부분 성공은 변환에 실패한 규칙을 조용히 지운다
            guard converted.count == rules.count else {
                throw RuntimeError("failed to convert apple calendar recurrence rules: \(rules)")
            }
            recurrenceRules = converted.isEmpty ? nil : converted
        }
    }

    private func applyEventTime(_ time: EventTime) {
        switch time {
        case .at(let point):
            isAllDay = false
            startDate = Date(timeIntervalSince1970: point)
            endDate = Date(timeIntervalSince1970: point)
        case .period(let range):
            isAllDay = false
            startDate = Date(timeIntervalSince1970: range.lowerBound)
            endDate = Date(timeIntervalSince1970: range.upperBound)
        case .allDay(let range, _):
            isAllDay = true
            startDate = Date(timeIntervalSince1970: range.lowerBound)
            endDate = Date(timeIntervalSince1970: range.upperBound)
        }
    }
}


// MARK: - String → URL

private extension String {

    func asEventURLOrNil() throws -> URL? {
        guard !self.isEmpty else { return nil }
        guard let parsed = URL(string: self) else {
            throw RuntimeError("failed to parse apple calendar event url: \(self)")
        }
        return parsed
    }
}


// MARK: - EKParticipant → AppleCalendar.Attendee

private extension EKParticipant {

    func asAppleCalendarAttendee() -> AppleCalendar.Attendee? {
        var attendee = AppleCalendar.Attendee(
            name: name,
            email: url.absoluteString.hasPrefix("mailto:") ? String(url.absoluteString.dropFirst(7)) : nil
        )
        attendee.isOrganizer = participantRole == .chair
        attendee.isCurrentUser = isCurrentUser
        attendee.status = participantStatus.asAttendeeStatus
        return attendee
    }
}

private extension EKParticipantStatus {

    var asAttendeeStatus: AppleCalendar.Attendee.Status {
        switch self {
        case .accepted:   return .accepted
        case .declined:   return .declined
        case .tentative:  return .tentative
        case .pending:    return .pending
        default:          return .unknown
        }
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
