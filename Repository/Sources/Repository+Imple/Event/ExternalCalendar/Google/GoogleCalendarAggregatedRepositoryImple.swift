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

    private let connectionPool: any ExternalCalendarDBConnectionPool
    private let accountRepository: any ExternalCalendarIntegrateRepository

    public init(
        connectionPool: any ExternalCalendarDBConnectionPool,
        accountRepository: any ExternalCalendarIntegrateRepository
    ) {
        self.connectionPool = connectionPool
        self.accountRepository = accountRepository
    }

    private func makeStorages() async throws -> [any GoogleCalendarLocalStorage] {
        let accounts = try await accountRepository.loadIntegratedAccounts()
        return accounts
            .filter { $0.serviceIdentifier == GoogleCalendarService.id }
            .compactMap { $0.email }
            .map { GoogleCalendarLocalStorageImple(connectionPool: connectionPool, accountId: $0) }
    }
}


extension GoogleCalendarAggregatedRepositoryImple {

    public func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        return self.load {
            let storages = try await self.makeStorages()
            var merged = GoogleCalendar.Colors(calendars: [:], events: [:])
            for storage in storages {
                guard let colors = try await storage.loadColors() else { continue }
                merged = GoogleCalendar.Colors(
                    calendars: merged.calendars.merging(colors.calendars) { $1 },
                    events: merged.events.merging(colors.events) { $1 }
                )
            }
            return merged
        }
    }

    public func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        return self.load {
            let storages = try await self.makeStorages()
            var allTags: [GoogleCalendar.Tag] = []
            for storage in storages {
                allTags += try await storage.loadCalendarList()
            }
            return allTags
        }
    }

    public func loadEvents(
        _ calendarId: String,
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        return self.load {
            let storages = try await self.makeStorages()
            var allEvents: [GoogleCalendar.Event] = []
            for storage in storages {
                allEvents += try await storage.loadEvents(calendarId, period)
            }
            return allEvents
        }
    }

    public func loadEventDetail(
        _ calendarId: String, _ timeZone: String, _ eventId: String
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        return self.load {
            let storages = try await self.makeStorages()
            for storage in storages {
                if let detail = try? await storage.loadEventDetail(eventId) {
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
