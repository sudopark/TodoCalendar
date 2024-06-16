//
//  ForemostLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 6/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


public protocol ForemostLocalStorage: AnyObject, Sendable {
 
    func loadForemostEvent() async throws -> (any ForemostMarkableEvent)?
    func updateForemostEvent(_ event: any ForemostMarkableEvent) async throws
    func updateForemostEventId(_ eventId: ForemostEventId) async throws
    func removeForemostEvent() async throws
}

public final class ForemostLocalStorageImple: ForemostLocalStorage {
    
    private let environmentStorage: any EnvironmentStorage
    private let todoStorage: any TodoLocalStorage
    private let scheduleStorage: any ScheduleEventLocalStorage
    
    public init(
        environmentStorage: any EnvironmentStorage,
        todoStorage: any TodoLocalStorage,
        scheduleStorage: any ScheduleEventLocalStorage
    ) {
        self.environmentStorage = environmentStorage
        self.todoStorage = todoStorage
        self.scheduleStorage = scheduleStorage
    }
    
    private let foremoestKey: String = "foremoset_event_id"
}
 

extension ForemostLocalStorageImple {
    
    public func loadForemostEvent() async throws -> (any ForemostMarkableEvent)? {
        let foremostId = self.loadForemostEventId()
        
        switch foremostId {
        case .some(let id) where id.isTodo == true:
            return try await self.todoStorage.loadTodoEvent(id.eventId)
            
        case .some(let id) where id.isTodo == false:
            return try await self.scheduleStorage.loadScheduleEvent(id.eventId)
            
        default:
            return nil
        }
        
    }
    
    private func loadForemostEventId() -> ForemostEventId? {
        let mapper: ForemostEventIdMapper? = self.environmentStorage.load(self.foremoestKey)
        return mapper?.id
    }
    
    public func updateForemostEvent(_ event: any ForemostMarkableEvent) async throws {
        try await self.updateForemostEventId(.init(event: event))
        
        switch event {
        case let todo as TodoEvent:
            try await self.todoStorage.updateTodoEvent(todo)
            
        case let schedule as ScheduleEvent:
            try await self.scheduleStorage.updateScheduleEvent(schedule)
            
        default: break
        }
    }
    
    public func updateForemostEventId(_ eventId: ForemostEventId) async throws {
        let mapper = ForemostEventIdMapper(id: eventId)
        self.environmentStorage.update(foremoestKey, mapper)
    }
    
    public func removeForemostEvent() async throws {
        self.environmentStorage.remove(foremoestKey)
    }
}
