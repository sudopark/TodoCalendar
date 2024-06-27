//
//  ForemostEventRemoteRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 6/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions


public final class ForemostEventRemoteRepositoryImple: ForemostEventRepository {
    
    private let remote: any RemoteAPI
    private let cacheStorage: any ForemostLocalStorage
    
    public init(
        remote: any RemoteAPI,
        cacheStorage: any ForemostLocalStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
    }
}


extension ForemostEventRemoteRepositoryImple {
    
    public func foremostEvent() -> AnyPublisher<(any ForemostMarkableEvent)?, any Error> {
        return AnyPublisher<(any ForemostMarkableEvent)?, any Error>.create { subscriber in
            let task = Task { [weak self] in
                
                do {
                    let cached = try await self?.cacheStorage.loadForemostEvent()
                    subscriber.send(cached)
                } catch { }
                
                do {
                    let refresed = try await self?.loadForemostEventFromRemote()
                    try await self?.replaceCache(refresed)
                    subscriber.send(refresed)
                    subscriber.send(completion: .finished)
                } catch {
                    subscriber.send(completion: .failure(error))
                }
            }
            return AnyCancellable { task.cancel() }
        }
        .eraseToAnyPublisher()
    }
    
    private func loadForemostEventFromRemote() async throws -> (any ForemostMarkableEvent)? {
        let endpoint = ForemostEventEndpoints.event
        let mapper: ForemostMarkableEventResponseMapper = try await self.remote.request(
            .get,
            endpoint
        )
        return mapper.event
    }
    
    private func replaceCache(_ foremost: (any ForemostMarkableEvent)?) async throws {
        if let event = foremost {
            try await self.cacheStorage.updateForemostEvent(event)
        } else {
            try await self.cacheStorage.removeForemostEvent()
        }
    }
    
    public func updateForemostEvent(_ eventId: ForemostEventId) async throws -> any ForemostMarkableEvent {
        let endpoint = ForemostEventEndpoints.event
        let mapper: ForemostMarkableEventResponseMapper = try await self.remote.request(
            .put,
            endpoint,
            parameters: eventId.asJson()
        )
        let event = try mapper.event.unwrap()
        try? await self.cacheStorage.updateForemostEvent(event)
        return event
    }
    
    public func removeForemostEvent() async throws {
        let endpoint = ForemostEventEndpoints.event
        let _: ForemostEventIdRemoveResponseMapper = try await self.remote.request(
            .delete,
            endpoint
        )
        try? await self.cacheStorage.removeForemostEvent()
    }
}
