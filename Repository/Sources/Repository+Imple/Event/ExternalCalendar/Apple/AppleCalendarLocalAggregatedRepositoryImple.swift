//
//  AppleCalendarLocalAggregatedRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import Domain


/// 위젯용 read-only Apple Calendar Repository.
/// DB 캐시에서만 읽는다.
public final class AppleCalendarLocalAggregatedRepositoryImple: AppleCalendarRepository {

    private let storage: any AppleCalendarLocalStorage

    public init(
        connectionPool: any ExternalCalendarDBConnectionPool
    ) {
        self.storage = AppleCalendarLocalStorageImple(connectionPool: connectionPool)
    }
}


// MARK: - AppleCalendarRepository

extension AppleCalendarLocalAggregatedRepositoryImple {

    public func loadCalendarTags() -> AnyPublisher<[AppleCalendar.Tag], any Error> {
        return load { [weak self] in
            return try await self?.storage.loadCalendarTags() ?? []
        }
    }

    public func loadEvents(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[AppleCalendar.Event], any Error> {
        return load { [weak self] in
            return try await self?.storage.loadEvents(in: period) ?? []
        }
    }

    public func loadEvent(id: String) -> AnyPublisher<AppleCalendar.Event?, Never> {
        return Just(nil).eraseToAnyPublisher()
    }

    public func resetCache() async throws { }

    private func load<T: Sendable>(
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
}
