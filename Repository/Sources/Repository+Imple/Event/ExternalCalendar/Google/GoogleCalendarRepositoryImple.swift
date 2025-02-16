//
//  GoogleCalendarRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import CombineExt
import SQLiteService
import Extensions


public final class GoogleCalendarRepositoryImple: GoogleCalendarRepository {
    
    private let remote: any RemoteAPI
    private let cacheStorage: any GoogleCalendarLocalStorage
    public init(
        remote: any RemoteAPI,
        cacheStorage: any GoogleCalendarLocalStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
    }
}


extension GoogleCalendarRepositoryImple {
    
    public func loadColors() -> AnyPublisher<GoogleCalendarColors, any Error> {
        
        return self.load { [weak self] in
            return try? await self?.cacheStorage.loadColors()
        } thenFromRemote: { [weak self] in
            return try await self?.loadColorsFromRemote()
        } withRefreshCache: { _, refreshed in
            guard let refreshed else { return }
            try? await self.cacheStorage.updateColors(refreshed)
        }
    }
    
    private func loadColorsFromRemote() async throws -> GoogleCalendarColors {
        let endpoint = GoogleCalendarEndpoint.colors
        let jsonData = try await self.remote.request(
            .get, endpoint, with: [:], parameters: [:]
        )
        let mapper = try GoogleCalendarColorsMapper(decode: jsonData)
        return mapper.colors
    }
    
    public func loadCalendarTags() -> AnyPublisher<[GoogleCalendarEventTag], any Error> {
        return self.load { [weak self] in
            return try? await self?.cacheStorage.loadCalendarList()
        } thenFromRemote: { [weak self] in
            return try await self?.loadCalendarTagsFromRemote()
        } withRefreshCache: { _, refreshed in
            guard let refreshed else { return }
            try? await self.cacheStorage.updateCalendarList(refreshed)
        }
    }
    
    private func loadCalendarTagsFromRemote() async throws -> [GoogleCalendarEventTag] {
        let endpoint = GoogleCalendarEndpoint.calednarList
        let mapper: GoogleCalendarEventTagListMapper = try await self.remote.request(
            .get, endpoint
        )
        return mapper.calendars
    }
    
    private func load<T>(
        startWith readCacheOperation: @Sendable @escaping () async throws -> T?,
        thenFromRemote remoteOperation: @Sendable @escaping () async throws -> T?,
        withRefreshCache replaceCacheOperation: (@Sendable (T?, T?) async -> Void)? = nil
    ) -> AnyPublisher<T, any Error> {
        
        return AnyPublisher<T?, any Error>.create { subscriber in
            let task = Task {
                let cached = try? await readCacheOperation()
                if let cached {
                    subscriber.send(cached)
                }
                
                do {
                    let refreshed = try await remoteOperation()
                    if let replaceOperation = replaceCacheOperation {
                        await replaceOperation(cached, refreshed)
                    }
                    subscriber.send(refreshed)
                    subscriber.send(completion: .finished)
                } catch {
                    subscriber.send(completion: .failure(error))
                }
            }
            return AnyCancellable { task.cancel() }
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
