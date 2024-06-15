//
//  ForemostEventLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 6/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions



public final class ForemostEventLocalRepositoryImple: ForemostEventRepository {
    
    private let envStorage: any EnvironmentStorage
    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleLocalStorage: any ScheduleEventLocalStorage
    public init(
        envStorage: any EnvironmentStorage,
        todoLocalStorage: any TodoLocalStorage,
        scheduleLocalStorage: any ScheduleEventLocalStorage
    ) {
        self.envStorage = envStorage
        self.todoLocalStorage = todoLocalStorage
        self.scheduleLocalStorage = scheduleLocalStorage
    }
    
    private let foremoestKey: String = "foremoset_event_id"
}


extension ForemostEventLocalRepositoryImple {
    
    public func foremostEvent() -> AnyPublisher<(any ForemostMarkableEvent)?, any Error> {
        return Publishers.create { [weak self] in
            guard let foremostId = self?.loadForemostId() else { return nil }
            return try await self?.loadForemost(foremostId)
        }
        .eraseToAnyPublisher()
    }
    
    private func loadForemostId() -> ForemostEventId? {
        let mapper: ForemostEventIdMapper? = self.envStorage.load(foremoestKey)
        return mapper?.id
    }
    
    private func loadForemost(_ id: ForemostEventId) async throws -> (any ForemostMarkableEvent)? {
        if id.isTodo {
            return try? await self.todoLocalStorage.loadTodoEvent(id.eventId)
        } else {
            return try? await self.scheduleLocalStorage.loadScheduleEvent(id.eventId)
        }
    }
    
    public func updateForemostEvent(_ eventId: ForemostEventId) async throws -> ForemostEventId {
        let mapper = ForemostEventIdMapper(id: eventId)
        self.envStorage.update(foremoestKey, mapper)
        return eventId
    }
    
    public func removeForemostEvent() async throws {
        self.envStorage.remove(foremoestKey)
    }
}
