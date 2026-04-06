//
//  AppleCalendarRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import Domain
import Extensions


public final class AppleCalendarRepositoryImple: AppleCalendarRepository, @unchecked Sendable {

    private let storeAccessor: any AppleCalendarStoreAccessor
    private let cacheStorage: any AppleCalendarLocalStorage

    public init(
        storeAccessor: any AppleCalendarStoreAccessor,
        cacheStorage: any AppleCalendarLocalStorage
    ) {
        self.storeAccessor = storeAccessor
        self.cacheStorage = cacheStorage
    }
}


// MARK: - AppleCalendarRepository

extension AppleCalendarRepositoryImple {

    public func loadCalendarTags() -> AnyPublisher<[AppleCalendar.Tag], any Error> {
        return AnyPublisher<[AppleCalendar.Tag]?, any Error>.create { [weak self] subscriber in
            let task = Task { [weak self] in
                guard let self else { return }
                let cached = try? await self.cacheStorage.loadCalendarTags()
                if let cached, !cached.isEmpty {
                    logger.log(.appleCalendar, level: .debug, "tags from cache", with: ["count": cached.count])
                    subscriber.send(cached)
                }
                let refreshed = self.storeAccessor.loadCalendarTags()
                let names = refreshed.map { $0.name }
                logger.log(.appleCalendar, level: .info, "tags refreshed from EventKit", with: ["count": refreshed.count, "names": names.joined(separator: ", ")])
                try? await self.cacheStorage.saveCalendarTags(refreshed)
                subscriber.send(refreshed)
                subscriber.send(completion: .finished)
            }
            return AnyCancellable { task.cancel() }
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }

    public func loadEvents(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[AppleCalendar.Event], any Error> {
        return AnyPublisher<[AppleCalendar.Event]?, any Error>.create { [weak self] subscriber in
            let task = Task { [weak self] in
                guard let self else { return }
                let cached = try? await self.cacheStorage.loadEvents(in: period)
                if let cached, !cached.isEmpty {
                    logger.log(.appleCalendar, level: .debug, "events from cache", with: ["count": cached.count, "period": self.periodDescription(period)])
                    subscriber.send(cached)
                }
                let refreshed = self.storeAccessor.loadEvents(in: period)
                logger.log(.appleCalendar, level: .info, "events refreshed from EventKit", with: ["count": refreshed.count, "period": self.periodDescription(period)])
                try? await self.cacheStorage.saveEvents(refreshed, in: period)
                subscriber.send(refreshed)
                subscriber.send(completion: .finished)
            }
            return AnyCancellable { task.cancel() }
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }

    public func loadEvent(id: String) -> AnyPublisher<AppleCalendar.Event?, Never> {
        return AnyPublisher<AppleCalendar.Event?, Never>.create { [weak self] subscriber in
            let task = Task { [weak self] in
                guard let self else { return }
                let cached = try? await self.cacheStorage.loadEvent(id: id)
                subscriber.send(cached)

                let originalId = cached?.originalEventId ?? id
                let master = self.storeAccessor.loadEvent(id: originalId)
                logger.log(.appleCalendar, level: .info, "event loaded from EventKit", with: ["id": id, "found": master != nil])

                if let cached, let master {
                    var merged = AppleCalendar.Event(
                        eventId: cached.eventId,
                        originalEventId: cached.originalEventId,
                        calendarId: cached.calendarId,
                        name: master.name,
                        eventTime: cached.eventTime
                    )
                    merged.isRepeating = cached.isRepeating
                    merged.location = master.location
                    subscriber.send(merged)
                } else {
                    subscriber.send(master)
                }
                subscriber.send(completion: .finished)
            }
            return AnyCancellable { task.cancel() }
        }
        .eraseToAnyPublisher()
    }

    public func resetCache() async throws {
        logger.log(.appleCalendar, level: .info, "cache reset")
        try await cacheStorage.resetAll()
    }

    private func periodDescription(_ period: Range<TimeInterval>) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.string(from: Date(timeIntervalSince1970: period.lowerBound))
        let end = formatter.string(from: Date(timeIntervalSince1970: period.upperBound))
        return "\(start) ~ \(end)"
    }
}
