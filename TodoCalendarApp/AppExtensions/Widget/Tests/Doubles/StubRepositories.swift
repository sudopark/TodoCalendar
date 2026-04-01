//
//  StubRepositories.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 6/7/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


final class StubExternalCalendarRepository: ExternalCalendarIntegrateRepository, @unchecked Sendable {

    private let isGoogleAccountIntegrated: Bool
    private let isAppleCalendarIntegrated: Bool
    init(
        isGoogleAccountIntegrated: Bool = false,
        isAppleCalendarIntegrated: Bool = false
    ) {
        self.isGoogleAccountIntegrated = isGoogleAccountIntegrated
        self.isAppleCalendarIntegrated = isAppleCalendarIntegrated
    }

    func loadIntegratedAccounts() async throws -> [ExternalServiceAccountinfo] {
        var accounts: [ExternalServiceAccountinfo] = []
        if isGoogleAccountIntegrated {
            accounts.append(.init(GoogleCalendarService.id, email: "some"))
        }
        if isAppleCalendarIntegrated {
            accounts.append(.init(AppleCalendarService.id, email: "local"))
        }
        return accounts
    }
    
    func save(_ credential: any OAuth2Credential, for service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo {
        throw RuntimeError("not support")
    }
    
    func removeAccount(for serviceIdentifier: String, accountId: String) async throws { }
}

final class StubGoogleCalendarRepository: GoogleCalendarRepository, @unchecked Sendable {
    
    func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        let colorSet = GoogleCalendar.Colors.ColorSet(foregroundHex: "for", backgroudHex: "back")
        let colors = GoogleCalendar.Colors(
            ownerId: "stub@google.com", calendars: ["c1": colorSet], events: ["e1": colorSet]
        )
        return Just(colors).mapAsAnyError().eraseToAnyPublisher()
    }
    
    func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        let tags: [GoogleCalendar.Tag] = [
            .init(id: "c1", name: "c1"), .init(id: "c2", name: "c2")
        ]
        return Just(tags).mapAsAnyError().eraseToAnyPublisher()
    }
    
    var eventMocking: [GoogleCalendar.Event]?
    func loadEvents(_ calendarId: String, in period: Range<TimeInterval>) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        if let eventMocking {
            return Just(eventMocking).mapAsAnyError().eraseToAnyPublisher()
        }
        let event = GoogleCalendar.Event(
            "e1", calendarId, accountId: "stub@gmail.com", name: "google", colorId: "e1", time: .period(period)
        )
        return Just([event]).mapAsAnyError().eraseToAnyPublisher()
    }
    
    func loadEventDetail(_ calendarId: String, _ timeZone: String, _ eventId: String) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    func resetCache() async throws { }
}

final class PrivateStubAppleCalendarRepository: AppleCalendarRepository, @unchecked Sendable {

    func loadCalendarTags() -> AnyPublisher<[AppleCalendar.Tag], any Error> {
        let tags: [AppleCalendar.Tag] = [
            .init(id: "a:1", name: "Work", colorHex: "#FF0000"),
            .init(id: "a:2", name: "Personal", colorHex: "#00FF00")
        ]
        return Just(tags).mapAsAnyError().eraseToAnyPublisher()
    }

    var eventMocking: [AppleCalendar.Event]?
    func loadEvents(in period: Range<TimeInterval>) -> AnyPublisher<[AppleCalendar.Event], any Error> {
        if let eventMocking {
            return Just(eventMocking).mapAsAnyError().eraseToAnyPublisher()
        }
        let event = AppleCalendar.Event(
            eventId: "ae1", calendarId: "a:1", name: "apple", eventTime: .period(period)
        )
        return Just([event]).mapAsAnyError().eraseToAnyPublisher()
    }

    func resetCache() async throws { }
}
