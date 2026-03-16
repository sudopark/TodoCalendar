//
//  GoogleCalendarAggregatedRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 12/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import Domain
import Extensions


public final class GoogleCalendarAggregatedRepositoryImple: GoogleCalendarRepository {

    private let storage: any GoogleCalendarLocalStorage
    private let accountRepository: any ExternalCalendarIntegrateRepository

    public init(
        connectionPool: any ExternalCalendarDBConnectionPool,
        accountRepository: any ExternalCalendarIntegrateRepository
    ) {
        self.storage = GoogleCalendarLocalStorageImple(connectionPool: connectionPool)
        self.accountRepository = accountRepository
    }

    private func googleAccountEmails() async throws -> [String] {
        let accounts = try await accountRepository.loadIntegratedAccounts()
        return accounts
            .filter { $0.serviceIdentifier == GoogleCalendarService.id }
            .compactMap { $0.email }
    }
}


extension GoogleCalendarAggregatedRepositoryImple {

    public func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        return self.load {
            let emails = try await self.googleAccountEmails()
            var merged = GoogleCalendar.Colors(ownerId: "", calendars: [:], events: [:])
            for email in emails {
                guard let colors = try await self.storage.loadColors(accountId: email) else { continue }
                merged = GoogleCalendar.Colors(
                    ownerId: "",
                    calendars: merged.calendars.merging(colors.calendars) { $1 },
                    events: merged.events.merging(colors.events) { $1 }
                )
            }
            return merged
        }
    }

    public func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        return self.load {
            let emails = try await self.googleAccountEmails()
            var allTags: [GoogleCalendar.Tag] = []
            for email in emails {
                allTags += try await self.storage.loadCalendarList(accountId: email)
            }
            return allTags
        }
    }

    public func loadEvents(
        _ calendarId: String,
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        return self.load {
            let emails = try await self.googleAccountEmails()
            var allEvents: [GoogleCalendar.Event] = []
            for email in emails {
                allEvents += try await self.storage.loadEvents(calendarId, period, accountId: email)
            }
            return allEvents
        }
    }

    public func loadEventDetail(
        _ calendarId: String, _ timeZone: String, _ eventId: String
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        return self.load {
            let emails = try await self.googleAccountEmails()
            for email in emails {
                if let detail = try? await self.storage.loadEventDetail(eventId, accountId: email) {
                    return detail
                }
            }
            throw RuntimeError("event detail not found: \(eventId)")
        }
    }

    private func load<T>(
        _ loading: @escaping @Sendable () async throws -> T
    ) -> AnyPublisher<T, any Error> {
        return AnyPublisher<T, any Error>.create { subscriber in
            let task = Task {
                do {
                    let value = try await loading()
                    subscriber.send(value)
                    subscriber.send(completion: .finished)
                } catch {
                    subscriber.send(completion: .failure(error))
                }
            }
            return AnyCancellable { task.cancel() }
        }
        .eraseToAnyPublisher()
    }

    public func resetCache() async throws { }
}
