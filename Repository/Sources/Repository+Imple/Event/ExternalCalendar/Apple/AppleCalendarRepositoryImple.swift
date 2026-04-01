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
                    subscriber.send(cached)
                }
                let refreshed = self.storeAccessor.loadCalendarTags()
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
                    subscriber.send(cached)
                }
                let refreshed = self.storeAccessor.loadEvents(in: period)
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
                let refreshed = self.storeAccessor.loadEvent(id: id)
                subscriber.send(refreshed)
                subscriber.send(completion: .finished)
            }
            return AnyCancellable { task.cancel() }
        }
        .eraseToAnyPublisher()
    }

    public func resetCache() async throws {
        try await cacheStorage.resetAll()
    }
}
