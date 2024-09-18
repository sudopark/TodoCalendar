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
    
    private let remoteAPI: any RemoteAPI
    private let cacheStorage: any EventDetailDataLocalStorage
    
    public init(
        remoteAPI: any RemoteAPI,
        cacheStorage: any EventDetailDataLocalStorage
    ) {
        self.remoteAPI = remoteAPI
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
                    let refreshed = try await self?.loadDetailFromRemote(id)
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
    
    private func loadDetailFromRemote(_ id: String) async throws -> EventDetailData {
        let endpoint: EventDetailEndpoints = .detail(eventId: id)
        let mapper: EventDetailDataMapper = try await self.remoteAPI.request(
            .get,
            endpoint
        )
        return mapper.data
    }
    
    public func saveDetail(_ detail: EventDetailData) async throws -> EventDetailData {
        let endpoint: EventDetailEndpoints = .detail(eventId: detail.eventId)
        let payload = detail.asJson()
        let mapper: EventDetailDataMapper = try await self.remoteAPI.request(
            .put,
            endpoint,
            parameters: payload
        )
        try? await self.cacheStorage.saveDetail(mapper.data)
        return mapper.data
    }
    
    public func removeDetail(_ id: String) async throws {
        let endpoint: EventDetailEndpoints = .detail(eventId: id)
        let _: RemoveTodoResultMapper = try await self.remoteAPI.request(
            .delete,
            endpoint
        )
        try? await self.cacheStorage.removeDetail(id)
    }
}
