//
//  GoogleCalendarReadOnlyRepositoryImple.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 12/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import Domain
import Extensions


public final class GoogleCalendarReadOnlyRepositoryImple: GoogleCalendarRepository {
    
    private let localStorage: any GoogleCalendarLocalStorage
    public init(localStorage: any GoogleCalendarLocalStorage) {
        self.localStorage = localStorage
    }
}


extension GoogleCalendarReadOnlyRepositoryImple {
    
    public func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        
        return self.load { [weak self] in
            return try await self?.localStorage.loadColors()
        }
    }
    
    public func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        return self.load { [weak self] in
            return try await self?.localStorage.loadCalendarList()
        }
    }
    
    public func loadEvents(
        _ calendarId: String,
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        
        return self.load { [weak self] in
            return try await self?.localStorage.loadEvents(calendarId, period)
        }
    }
    
    public func loadEventDetail(_ calendarId: String, _ timeZone: String, _ eventId: String) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        
        return self.load { [weak self] in
            return try await self?.localStorage.loadEventDetail(eventId)
        }
    }
    
    private func load<T>(
        _ loading: @escaping @Sendable () async throws -> T?
    ) -> AnyPublisher<T, any Error> {
        
        return AnyPublisher<T?, any Error>.create { subscriber in
            
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
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
    
    public func resetCache() async throws { }
}
