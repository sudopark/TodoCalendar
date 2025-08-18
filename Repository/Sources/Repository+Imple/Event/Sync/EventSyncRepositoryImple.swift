//
//  EventSyncRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 7/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain


public final class EventSyncRepositoryImple: EventSyncRepository {
    
    private let remote: any RemoteAPI
    private let syncTimestampLocalStorage: any EventSyncTimestampLocalStorage
    private let eventTagLocalStorage: any EventTagLocalStorage
    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleLocalStorage: any ScheduleEventLocalStorage
    
    public init(
        remote: any RemoteAPI,
        syncTimestampLocalStorage: any EventSyncTimestampLocalStorage,
        eventTagLocalStorage: any EventTagLocalStorage,
        todoLocalStorage: any TodoLocalStorage,
        scheduleLocalStorage: any ScheduleEventLocalStorage
    ) {
        self.remote = remote
        self.syncTimestampLocalStorage = syncTimestampLocalStorage
        self.eventTagLocalStorage = eventTagLocalStorage
        self.todoLocalStorage = todoLocalStorage
        self.scheduleLocalStorage = scheduleLocalStorage
    }
}


extension EventSyncRepositoryImple {
    
    public func checkIsNeedSync(
        for dataType: SyncDataType
    ) async throws -> EventSyncCheckRespose {
        
        let timestamp = try await self.syncTimestampLocalStorage.loadLocalTimestamp(for: dataType)
        let endpoint = EventSyncEndPoints.check
        var payload: [String: Any] = [ "dataType": dataType.rawValue ]
        payload["timestamp"] = timestamp?.timeStampInt
        
        let mapper: EventSyncCheckResposeMapper = try await self.remote.request(
            .get, endpoint, parameters: payload
        )
        return mapper.response
    }
    
    public func startSync<T: Sendable>(
        for dataType: SyncDataType, startFrom timestamp: Int?, pageSize: Int
    ) async throws -> EventSyncResponse<T> {
        
        let endpoint = EventSyncEndPoints.start
        var payload: [String: Any] = [
            "dataType": dataType.rawValue,
            "size": pageSize
        ]
        payload["timestamp"] = timestamp
        
        let mapper: EventSyncResponseMapper<T> = try await self.remote.request(
            .get, endpoint, parameters: payload
        )
        try await self.handleSyncResponse(dataType, mapper.response)
        return mapper.response
    }
    
    public func continueSync<T: Sendable>(
        for dataType: SyncDataType, cursor: String, pageSize: Int
    ) async throws -> EventSyncResponse<T> {
        
        let endpoint = EventSyncEndPoints.continue
        let payload: [String: Any] = [
            "dataType": dataType.rawValue,
            "cursor": cursor,
            "size": pageSize
        ]
        let mapper: EventSyncResponseMapper<T> = try await self.remote.request(
            .get, endpoint, parameters: payload
        )
        try await self.handleSyncResponse(dataType, mapper.response)
        return mapper.response
    }
}

extension EventSyncRepositoryImple {
    
    private func handleSyncResponse<T>(
        _ dataType: SyncDataType,
        _ syncResponse: EventSyncResponse<T>
    ) async throws {
        try await updateCreatedOrUpdated(dataType, created: syncResponse.created, updated: syncResponse.updated)
        try await deleteRemoved(dataType, syncResponse.deletedIds)
        
        guard let timeStamp = syncResponse.newSyncTime else { return }
        try await self.syncTimestampLocalStorage.updateLocalTimestamp(by: .init(dataType, timeStamp))
    }
    
    private func updateCreatedOrUpdated<T>(
        _ dataType: SyncDataType,
        created: [T]?, updated: [T]?
    ) async throws {
        let total = (created ?? []) + (updated ?? [])
        guard !total.isEmpty else { return }
        switch dataType {
        case .eventTag:
            let tags = total.compactMap { $0 as? CustomEventTag }
            try await self.eventTagLocalStorage.updateTags(tags)
            
        case .todo:
            let todos = total.compactMap { $0 as? TodoEvent }
            try await self.todoLocalStorage.updateTodoEvents(todos)
            
        case .schedule:
            let schedules = total.compactMap { $0 as? ScheduleEvent }
            try await self.scheduleLocalStorage.updateScheduleEvents(schedules)
        }
    }
    
    private func deleteRemoved(
        _ dataType: SyncDataType, _ ids: [String]?
    ) async throws {
        guard let ids = ids, !ids.isEmpty else { return }
        
        switch dataType {
        case .eventTag:
            try await self.eventTagLocalStorage.deleteTags(ids)
            
        case .todo:
            try await self.todoLocalStorage.removeTodos(ids)
            
        case .schedule:
            try await self.scheduleLocalStorage.removeScheduleEvents(ids)
        }
    }
}
