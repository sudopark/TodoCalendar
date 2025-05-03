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


public final class GoogleCalendarRepositoryImple: GoogleCalendarRepository, @unchecked Sendable {
    
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


// MARK: - load colors and tags

extension GoogleCalendarRepositoryImple {
    
    public func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        
        return self.load { [weak self] in
            return try? await self?.cacheStorage.loadColors()
        } thenFromRemote: { [weak self] in
            return try await self?.loadColorsFromRemote()
        } withRefreshCache: { _, refreshed in
            guard let refreshed else { return }
            try? await self.cacheStorage.updateColors(refreshed)
        }
    }
    
    private func loadColorsFromRemote() async throws -> GoogleCalendar.Colors {
        let endpoint = GoogleCalendarEndpoint.colors
        let jsonData = try await self.remote.request(
            .get, endpoint, with: [:], parameters: [:]
        )
        let mapper = try GoogleCalendarColorsMapper(decode: jsonData)
        return mapper.colors
    }
    
    public func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        return self.load { [weak self] in
            return try? await self?.cacheStorage.loadCalendarList()
        } thenFromRemote: { [weak self] in
            return try await self?.loadCalendarTagsFromRemote()
        } withRefreshCache: { _, refreshed in
            guard let refreshed else { return }
            try? await self.cacheStorage.updateCalendarList(refreshed)
        }
    }
    
    private func loadCalendarTagsFromRemote() async throws -> [GoogleCalendar.Tag] {
        let endpoint = GoogleCalendarEndpoint.calednarList
        let mapper: GoogleCalendarEventTagListMapper = try await self.remote.request(
            .get, endpoint
        )
        return mapper.calendars
    }
}


// MARK: - load events

extension GoogleCalendarRepositoryImple {
    
    public func loadEvents(
        _ calendarId: String,
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        
        return AnyPublisher<[GoogleCalendar.Event]?, any Error>.create { @Sendable [weak self] subscriber in
            let task = Task {
                let cached = try? await self?.cacheStorage.loadEvents(calendarId, period)
                if let cached {
                    subscriber.send(cached)
                }
                
                do {
                    let refreshedList = try await self?.loadEventOriginListFromRemote(calendarId, in: period)
                    
                    let events = refreshedList?.items.compactMap {
                        return GoogleCalendar.Event($0, calendarId, refreshedList?.timeZone)
                    }
                    if let cached {
                        try? await self?.cacheStorage.removeEvents(cached.map { $0.eventId })
                    }
                    if let refreshedList, let events {
                        try? await self?.cacheStorage.updateEvents(
                            calendarId, refreshedList, events
                        )
                    }
                    subscriber.send(events)
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
    
    public func loadEventDetail(
        _ calendarId: String, _ timeZone: String, _ eventId: String
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        
        return self.load { [weak self] in
            return try await self?.cacheStorage.loadEventDetail(eventId)
        } thenFromRemote: { [weak self] in
            return try await self?.loadEventDetailFromRemote(calendarId, eventId, at: timeZone)
        } withRefreshCache: { _, refreshed in
            guard let refreshed else { return }
            try? await self.cacheStorage.updateEventDetail(calendarId, timeZone, refreshed)
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
    
    private func loadEventOriginListFromRemote(
        _ calendarId: String, in period: Range<TimeInterval>
    ) async throws -> GoogleCalendar.EventOriginValueList {
        
        let (timeMin, timeMax) = self.timeMinAndMax(period)
        
        var nextPageToken: String?
        var accList = GoogleCalendar.EventOriginValueList()
        repeat {
            let list = try await self.loadEventFromRemote(calendarId, timeMin, timeMax, next: nextPageToken)
            nextPageToken = list.nextPageToken
            accList.timeZone = list.timeZone
            accList.items.append(contentsOf: list.items)
        } while nextPageToken != nil
        
        return accList
    }
    
    private func loadEventFromRemote(
        _ calendarId: String,
        _ timeMin: String, _ timeMax: String,
        next: String?
    ) async throws -> GoogleCalendar.EventOriginValueList {
        let id = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let endpoint = GoogleCalendarEndpoint.eventList(calendarId: id)
        var params: [String: Any] = [:]
        params["timeMin"] = timeMin; params["timeMax"] = timeMax
        params["singleEvents"] = true
        params["pageToken"] = next
        
        let list: GoogleCalendar.EventOriginValueList = try await self.remote.request(
            .get, endpoint,
            parameters: params
        )
        return list
    }
    
    private func loadEventDetailFromRemote(
        _ calendarId: String,
        _ eventId: String,
        at timeZone: String
    ) async throws -> GoogleCalendar.EventOrigin {
        let endpoint = GoogleCalendarEndpoint.event(calendarId: calendarId, eventId: eventId)
        let params: [String: Any] = [
            "timeZone": timeZone
        ]
        let origin: GoogleCalendar.EventOrigin = try await self.remote.request(
            .get, endpoint,
            parameters: params
        )
        return origin
    }
    
    private func timeMinAndMax(_ period: Range<TimeInterval>) -> (String, String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .init(secondsFromGMT: 0)
        
        return (
            formatter.string(from: Date(timeIntervalSince1970: period.lowerBound)),
            formatter.string(from: Date(timeIntervalSince1970: period.upperBound))
        )
    }
}


extension GoogleCalendarRepositoryImple {
    
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
