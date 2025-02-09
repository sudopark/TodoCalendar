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
        
        return AnyPublisher<GoogleCalendarColors, any Error>.create { subscriber in
            let task = Task { [weak self] in
                
                if let cached = try? await self?.cacheStorage.loadColors() {
                    subscriber.send(cached)
                }
                
                do {
                    guard let refreshed = try await self?.loadColorsFromRemote()
                    else {
                        subscriber.send(completion: .finished)
                        return
                    }
                    try? await self?.cacheStorage.updateColors(refreshed)
                    subscriber.send(refreshed)
                    subscriber.send(completion: .finished)
                    
                } catch {
                    subscriber.send(completion: .failure(error))
                }
            }
            
            return AnyCancellable { task.cancel() }
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
}
