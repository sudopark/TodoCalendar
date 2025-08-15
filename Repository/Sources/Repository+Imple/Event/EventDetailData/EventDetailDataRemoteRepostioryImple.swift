//
//  EventDetailDataRemoteRepostioryImple.swift
//  Repository
//
//  Created by sudo.park on 4/7/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import AsyncFlatMap

public final class EventDetailDataRemoteRepostioryImple: EventDetailDataRepository, Sendable {
    
    private let remote: any EventDetailRemote
    private let cacheStorage: any EventDetailDataLocalStorage
    
    public init(
        remote: any EventDetailRemote,
        cacheStorage: any EventDetailDataLocalStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
    }
}

extension EventDetailDataRemoteRepostioryImple {
    
    public func loadDetail(_ id: String) -> AnyPublisher<EventDetailData, any Error> {
        let loading = AnyPublisher<EventDetailData?, any Error>.create { subscriber in
            let task = Task { [weak self] in
                let cached = try? await self?.cacheStorage.loadDetail(id)
                if let cached {
                    subscriber.send(cached)
                }
                
                do {
                    let refreshed = try await self?.remote.loadDetail(id)
                    if let refreshed {
                        
                        try? await self?.cacheStorage.saveDetail(refreshed)
                        
                        subscriber.send(refreshed)
                        subscriber.send(completion: .finished)
                    }
                } catch {
                    subscriber.send(completion: .failure(error))
                }
            }
            return AnyCancellable { task.cancel() }
        }
        return loading
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public func saveDetail(_ detail: EventDetailData) async throws -> EventDetailData {
        let data = try await self.remote.saveDetail(detail)
        try? await self.cacheStorage.saveDetail(data)
        return data
    }
    
    public func removeDetail(_ id: String) async throws {
        try await self.remote.removeDetail(id)
        try? await self.cacheStorage.removeDetail(id)
    }
}
