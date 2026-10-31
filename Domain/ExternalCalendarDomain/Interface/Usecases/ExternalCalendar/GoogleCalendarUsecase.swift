//
//  GoogleCalendarUsecase.swift
//  ExternalCalendarDomainInterface
//
//  Created by sudo.park on 2/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions

// MARK: - GoogleCalendarViewAppearanceStore

public protocol GoogleCalendarViewAppearanceStore: Sendable {

    func applyColors(_ colors: GoogleCalendar.Colors, for accountId: String)
    func clearColors(for accountId: String)

    func applyCalendarTags(_ tags: [GoogleCalendar.Tag], for accountId: String)
    func clearCalendarTags(for accountId: String)
}


// MARK: - GoogleCalendarUsecase

public protocol GoogleCalendarUsecase: Sendable {

    var googleService: GoogleCalendarService { get }

    func prepare()

    // calendar
    func refreshGoogleCalendarEventTags()

    var calendarTags: AnyPublisher<[GoogleCalendar.Tag], Never> { get }

    // events
    func refreshEvents(in period: Range<TimeInterval>)

    func refreshRepeatingEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        in period: Range<TimeInterval>
    )

    func events(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], Never>

    func eventDetail(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error>

    func eventWritePermission(
        accountId: String, calendarId: String
    ) -> AnyPublisher<GoogleCalendar.EventWritePermission, Never>

    func updateEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        at timeZone: TimeZone,
        params: GoogleCalendar.EventEditParams
    ) async throws -> GoogleCalendar.EventOrigin

    func respondToEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        at timeZone: TimeZone,
        responseStatus: GoogleCalendar.AttendeeResponseStatus
    ) async throws -> GoogleCalendar.EventOrigin

    func removeEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        scope: GoogleCalendar.EventRemoveScope
    ) async throws
}

public extension GoogleCalendar.Tag {

    public var isHoliday: Bool {
        return id.hasSuffix("holiday@group.v.calendar.google.com")
    }
}


// MARK: - GoogleCalendar.EventWritePermission

extension GoogleCalendar {

    public enum EventWritePermission: Sendable, Equatable {
        case writable
        case needReauthentication
        case readOnlyCalendar

        public init(account: ExternalServiceAccountinfo?, calendar: GoogleCalendar.Tag?) {
            guard calendar?.isWritable == true else {
                self = .readOnlyCalendar
                return
            }
            guard account?.canWriteGoogleCalendar == true else {
                self = .needReauthentication
                return
            }
            self = .writable
        }
    }
}
