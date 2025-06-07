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
    init(isGoogleAccountIntegrated: Bool) {
        self.isGoogleAccountIntegrated = isGoogleAccountIntegrated
    }
    
    func loadIntegratedAccounts() async throws -> [ExternalServiceAccountinfo] {
        let account = ExternalServiceAccountinfo(
            GoogleCalendarService.id, email: "some"
        )
        return isGoogleAccountIntegrated ? [account] : []
    }
    
    func save(_ credential: any OAuth2Credential, for service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo {
        throw RuntimeError("not support")
    }
    
    func removeAccount(for serviceIdentifier: String) async throws { }
}

final class StubGoogleCalendarRepository: GoogleCalendarRepository, @unchecked Sendable {
    
    func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        let colorSet = GoogleCalendar.Colors.ColorSet(foregroundHex: "for", backgroudHex: "back")
        let colors = GoogleCalendar.Colors(
            calendars: ["c1": colorSet], events: ["e1": colorSet]
        )
        return Just(colors).mapAsAnyError().eraseToAnyPublisher()
    }
    
    func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        let tags: [GoogleCalendar.Tag] = [
            .init(id: "c1", name: "c1"), .init(id: "c2", name: "c2")
        ]
        return Just(tags).mapAsAnyError().eraseToAnyPublisher()
    }
    
    func loadEvents(_ calendarId: String, in period: Range<TimeInterval>) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        let event = GoogleCalendar.Event(
            "e1", calendarId, name: "google", colorId: "e1", time: .period(period)
        )
        return Just([event]).mapAsAnyError().eraseToAnyPublisher()
    }
    
    func loadEventDetail(_ calendarId: String, _ timeZone: String, _ eventId: String) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        return Empty().eraseToAnyPublisher()
    }
}
