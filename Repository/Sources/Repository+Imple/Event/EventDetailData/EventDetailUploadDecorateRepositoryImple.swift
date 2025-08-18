//
//  EventDetailUploadDecorateRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import CombineExt


public final class EventDetailUploadDecorateRepositoryImple: EventDetailDataRepository, Sendable {
    
    private let remote: any EventDetailRemote
    private let cacheStorage: any EventDetailDataLocalStorage
    private let uploadService: any EventUploadService
    
    public init(
        remote: any EventDetailRemote,
        cacheStorage: any EventDetailDataLocalStorage,
        uploadService: any EventUploadService
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
        self.uploadService = uploadService
    }
}

extension EventDetailUploadDecorateRepositoryImple {
    
    public func loadDetail(
        _ id: String
    ) -> AnyPublisher<EventDetailData, any Error> {
        
        let loading = AnyPublisher<EventDetailData?, any Error>.create { subscriber in
            
            let task = Task { [weak self] in
                let cached = try await self?.cacheStorage.loadDetail(id)
                subscriber.send(cached)
                
                let refreshed = try? await self?.remote.loadDetail(id)
                if let refreshed {
                    try? await self?.cacheStorage.saveDetail(refreshed)
                }
                
                subscriber.send(refreshed)
                subscriber.send(completion: .finished)
            }
            
            return AnyCancellable { task.cancel() }
        }
        
        return loading
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public func saveDetail(
        _ detail: EventDetailData
    ) async throws -> EventDetailData {
        try await self.cacheStorage.saveDetail(detail)
        try await self.uploadService.append(
            .init(dataType: .eventDetail, uuid: detail.eventId, isRemovingTask: false)
        )
        return detail
    }
    
    public func removeDetail(_ id: String) async throws {
        try await self.cacheStorage.removeDetail(id)
        try await self.uploadService.append(
            .init(dataType: .eventDetail, uuid: id, isRemovingTask: true)
        )
    }
}
