//
//  EventSyncRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 7/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import SQLiteService
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("EventSyncRepositoryImpleTests", .serialized)
final class EventSyncRepositoryImpleTests: PublisherWaitable, LocalTestable {
    
    var cancelBag: Set<AnyCancellable>! = []
    let sqliteService: SQLiteService = .init()
    
    private let syncTimestampLocalStorage: EventSyncTimestampLocalStorageImple
    private let eventTagLocalStorage: EventTagLocalStorageImple
    private let todoLocalStorage: TodoLocalStorageImple
    private let scheduleLocalStorage: ScheduleEventLocalStorageImple
    
    private let stubRemote: StubRemoteAPI
    
    init() {
        self.syncTimestampLocalStorage = .init(sqliteService: self.sqliteService)
        self.eventTagLocalStorage = .init(sqliteService: self.sqliteService)
        self.todoLocalStorage = .init(sqliteService: self.sqliteService)
        self.scheduleLocalStorage = .init(sqliteService: self.sqliteService)
        
        self.stubRemote = .init(responses: DummyResponse().response)
    }
    
    private func makeRepository() -> EventSyncRepositoryImple {
        return EventSyncRepositoryImple(
            remote: self.stubRemote,
            syncTimestampLocalStorage: self.syncTimestampLocalStorage,
            eventTagLocalStorage: self.eventTagLocalStorage,
            todoLocalStorage: self.todoLocalStorage,
            scheduleLocalStorage: self.scheduleLocalStorage
        )
    }
    
    private func saveTimeStamp(_ dataType: SyncDataType, _ ts: Int) async throws {
        let timestamp = EventSyncTimestamp(dataType, ts)
        try await self.syncTimestampLocalStorage.updateLocalTimestamp(by: timestamp)
        
    }
}

// MARK: - check sync

extension EventSyncRepositoryImpleTests {
    
    struct SyncCheckTestInput {
        let dataType: SyncDataType
        let timestamp: Int
        var dbName: String {
            return "\(dataType.rawValue)_\(timestamp)"
        }
    }
    
    
    @Test("check is need sync", arguments: [
        SyncCheckTestInput(dataType: .eventTag, timestamp: Int.syncWithMigrationNeedTimestamp),
        .init(dataType: .eventTag, timestamp: Int.syncNotNeedTimestamp),
        .init(dataType: .eventTag, timestamp: Int.syncNeedTimestamp),
        
        .init(dataType: .todo, timestamp: Int.syncWithMigrationNeedTimestamp),
        .init(dataType: .todo, timestamp: Int.syncNotNeedTimestamp),
        .init(dataType: .todo, timestamp: Int.syncNeedTimestamp),
        
        .init(dataType: .schedule, timestamp: Int.syncWithMigrationNeedTimestamp),
        .init(dataType: .schedule, timestamp: Int.syncNotNeedTimestamp),
        .init(dataType: .schedule, timestamp: Int.syncNeedTimestamp)
    ])
    func respository_checkIsNeedSync(_ input: SyncCheckTestInput) async throws {
        try await self.runTestWithOpenClose(input.dbName) {
            // given
            try await self.saveTimeStamp(input.dataType, input.timestamp)
            let repository = self.makeRepository()
            
            // when
            let response = try await repository.checkIsNeedSync(for: input.dataType)
            
            // then
            switch input.timestamp {
            case Int.syncWithMigrationNeedTimestamp:
                #expect(response.result == .migrationNeeds)
                #expect(response.startTimestamp == nil)
                
            case Int.syncNotNeedTimestamp:
                #expect(response.result == .noNeedToSync)
                #expect(response.startTimestamp == nil)
                
            case Int.syncNeedTimestamp:
                #expect(response.result == .needToSync)
                #expect(response.startTimestamp == Int.syncNeedTimestamp)
            default:
                Issue.record("기대한 갑싱 아님")
            }
        }
    }
}

// MARK: - sync tag

extension EventSyncRepositoryImpleTests {
    
    private func saveOldTags() async throws {
        let tags = (1...4).map { int in
            return CustomEventTag(uuid: "t\(int)", name: "old:\(int)", colorHex: "hex")
        }
        try await self.eventTagLocalStorage.updateTags(tags)
    }
    
    @Test("startSync tag", arguments: [false, true])
    func respository_startTag(isLast: Bool) async throws {
        try await self.runTestWithOpenClose("start_tag_isLast\(isLast)") {
            // given
            try await self.saveOldTags()
            let repository = self.makeRepository()
            
            // when
            let startFrom = isLast ? 100 : nil
            let response: EventSyncResponse<CustomEventTag> = try await repository.startSync(
                for: .eventTag, startFrom: startFrom, pageSize: 20
            )
            
            // then
            try await self.assertTagResponseAndCache(response, isLast: isLast)
        }
    }
    
    @Test("continueSync tag", arguments: [false, true])
    func respository_continueTag(isLast: Bool) async throws {
        try await self.runTestWithOpenClose("continue_tag_isLast\(isLast)") {
            // given
            try await self.saveOldTags()
            let repository = self.makeRepository()
            
            // when
            let cursor = isLast ? "end" : "next"
            let response: EventSyncResponse<CustomEventTag> = try await repository.continueSync(for: .eventTag, cursor: cursor, pageSize: 20)
            
            // then
            try await self.assertTagResponseAndCache(response, isLast: isLast)
        }
    }
    
    private func assertTagResponseAndCache(
        _ response: EventSyncResponse<CustomEventTag>, isLast: Bool
    ) async throws {
        #expect(response.created?.map { $0.uuid } == ["t5", "t6"])
        #expect(response.updated?.map { $0.uuid } == ["t3", "t4"])
        #expect(response.deletedIds == ["t1", "t2"])
        if isLast {
            #expect(response.nextPageCursor == nil)
            #expect(response.newSyncTime == .init(.eventTag, 200))
        } else {
            #expect(response.nextPageCursor == "next")
            #expect(response.newSyncTime == nil)
        }
        
        let tags = try await self.eventTagLocalStorage.loadAllTags().sorted(by: { $0.uuid < $1.uuid })
        let ids = tags.map { $0.uuid }; let names = tags.map { $0.name }
        #expect(ids == ["t3", "t4", "t5", "t6"])
        #expect(names == [ "updated_3", "updated_4", "new_tag5", "new_tag6"])
        
        if isLast {
            let timestamp = try await self.syncTimestampLocalStorage.loadLocalTimestamp(for: .eventTag)
            #expect(timestamp == .init(.eventTag, 200))
        }
    }
}

// MARK: - sync todo

extension EventSyncRepositoryImpleTests {
    
    private func saveOldTodos() async throws {
        let todos = (1...4).map { int in
            return TodoEvent(uuid: "t\(int)", name: "old:\(int)")
        }
        try await self.todoLocalStorage.updateTodoEvents(todos)
    }
    
    @Test("startSync todo", arguments: [false, true])
    func respository_startTodo(isLast: Bool) async throws {
        try await self.runTestWithOpenClose("start_todo_isLast\(isLast)") {
            // given
            try await self.saveOldTodos()
            let repository = self.makeRepository()
            
            // when
            let startFrom = isLast ? 100 : nil
            let response: EventSyncResponse<TodoEvent> = try await repository.startSync(
                for: .todo, startFrom: startFrom, pageSize: 20
            )
            
            // then
            try await self.assertTodoResponseAndCache(response, isLast: isLast)
        }
    }
    
    @Test("continueSync tag", arguments: [false, true])
    func respository_continueTodo(isLast: Bool) async throws {
        try await self.runTestWithOpenClose("continue_todo_isLast\(isLast)") {
            // given
            try await self.saveOldTodos()
            let repository = self.makeRepository()
            
            // when
            let cursor = isLast ? "end" : "next"
            let response: EventSyncResponse<TodoEvent> = try await repository.continueSync(for: .todo, cursor: cursor, pageSize: 20)
            
            // then
            try await self.assertTodoResponseAndCache(response, isLast: isLast)
        }
    }
    
    private func assertTodoResponseAndCache(
        _ response: EventSyncResponse<TodoEvent>, isLast: Bool
    ) async throws {
        #expect(response.created?.map { $0.uuid } == ["t5", "t6"])
        #expect(response.updated?.map { $0.uuid } == ["t3", "t4"])
        #expect(response.deletedIds == ["t1", "t2"])
        if isLast {
            #expect(response.nextPageCursor == nil)
            #expect(response.newSyncTime == .init(.todo, 200))
        } else {
            #expect(response.nextPageCursor == "next")
            #expect(response.newSyncTime == nil)
        }
        
        let todos = try await self.todoLocalStorage.loadAllEvents().sorted(by: { $0.uuid < $1.uuid })
        let ids = todos.map { $0.uuid }; let names = todos.map { $0.name }
        #expect(ids == ["t3", "t4", "t5", "t6"])
        #expect(names == [ "updated_3", "updated_4", "new_5", "new_6"])
        
        if isLast {
            let timestamp = try await self.syncTimestampLocalStorage.loadLocalTimestamp(for: .todo)
            #expect(timestamp == .init(.todo, 200))
        }
    }
}

// MARK: - sync schedule

extension EventSyncRepositoryImpleTests {
    
    private func saveOldSchedules() async throws {
        let schedules = (1...4).map { int in
            return ScheduleEvent(uuid: "sc\(int)", name: "old:\(int)", time: .at(0))
        }
        try await self.scheduleLocalStorage.updateScheduleEvents(schedules)
    }
    
    @Test("startSync schedule", arguments: [false, true])
    func respository_startSchedule(isLast: Bool) async throws {
        try await self.runTestWithOpenClose("start_schedule_isLast\(isLast)") {
            // given
            try await self.saveOldSchedules()
            let repository = self.makeRepository()
            
            // when
            let startFrom = isLast ? 100 : nil
            let response: EventSyncResponse<ScheduleEvent> = try await repository.startSync(
                for: .schedule, startFrom: startFrom, pageSize: 20
            )
            
            // then
            try await self.assertScheduleResponseAndCache(response, isLast: isLast)
        }
    }
    
    @Test("continueSync schedule", arguments: [false, true])
    func respository_continueSchedule(isLast: Bool) async throws {
        try await self.runTestWithOpenClose("continue_schedule_isLast\(isLast)") {
            // given
            try await self.saveOldSchedules()
            let repository = self.makeRepository()
            
            // when
            let cursor = isLast ? "end" : "next"
            let response: EventSyncResponse<ScheduleEvent> = try await repository.continueSync(for: .schedule, cursor: cursor, pageSize: 20)
            
            // then
            try await self.assertScheduleResponseAndCache(response, isLast: isLast)
        }
    }
    
    private func assertScheduleResponseAndCache(
        _ response: EventSyncResponse<ScheduleEvent>, isLast: Bool
    ) async throws {
        #expect(response.created?.map { $0.uuid } == ["sc5", "sc6"])
        #expect(response.updated?.map { $0.uuid } == ["sc3", "sc4"])
        #expect(response.deletedIds == ["sc1", "sc2"])
        if isLast {
            #expect(response.nextPageCursor == nil)
            #expect(response.newSyncTime == .init(.schedule, 200))
        } else {
            #expect(response.nextPageCursor == "next")
            #expect(response.newSyncTime == nil)
        }
        
        let events = try await self.scheduleLocalStorage.loadAllEvents().sorted(by: { $0.uuid < $1.uuid })
        let ids = events.map { $0.uuid }; let names = events.map { $0.name }
        #expect(ids == ["sc3", "sc4", "sc5", "sc6"])
        #expect(names == [ "updated_3", "updated_4", "new_5", "new_6"])
        
        if isLast {
            let timestamp = try await self.syncTimestampLocalStorage.loadLocalTimestamp(for: .schedule)
            #expect(timestamp == .init(.schedule, 200))
        }
    }
}

private struct DummyResponse {
    
    var response: [StubRemoteAPI.Response] {
        return [
            // tags
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int == Int.syncWithMigrationNeedTimestamp
                },
                resultJsonString: .success(self.migrationNeedResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int == Int.syncNotNeedTimestamp
                },
                resultJsonString: .success(self.noNeedToSyncResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int == Int.syncNeedTimestamp
                },
                resultJsonString: .success(self.syncNeedResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.start,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int == nil
                },
                resultJsonString: .success(self.syncTagResponse(isLast: false))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.start,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int != nil
                },
                resultJsonString: .success(self.syncTagResponse(isLast: true))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.continue,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["cursor"] as? String == "next"
                },
                resultJsonString: .success(self.syncTagResponse(isLast: false))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.continue,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["cursor"] as? String == "end"
                },
                resultJsonString: .success(self.syncTagResponse(isLast: true))
            ),
            
            // todos
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int == Int.syncWithMigrationNeedTimestamp
                },
                resultJsonString: .success(self.migrationNeedResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int == Int.syncNotNeedTimestamp
                },
                resultJsonString: .success(self.noNeedToSyncResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int == Int.syncNeedTimestamp
                },
                resultJsonString: .success(self.syncNeedResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.start,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int == nil
                },
                resultJsonString: .success(self.syncTodoResponse(isLast: false))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.start,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int != nil
                },
                resultJsonString: .success(self.syncTodoResponse(isLast: true))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.continue,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["cursor"] as? String == "next"
                },
                resultJsonString: .success(self.syncTodoResponse(isLast: false))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.continue,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["cursor"] as? String == "end"
                },
                resultJsonString: .success(self.syncTodoResponse(isLast: true))
            ),
            
            // schedules
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int == Int.syncWithMigrationNeedTimestamp
                },
                resultJsonString: .success(self.migrationNeedResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int == Int.syncNotNeedTimestamp
                },
                resultJsonString: .success(self.noNeedToSyncResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.check,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int == Int.syncNeedTimestamp
                },
                resultJsonString: .success(self.syncNeedResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.start,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int == nil
                },
                resultJsonString: .success(self.syncScheduleResponse(isLast: false))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.start,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int != nil
                },
                resultJsonString: .success(self.syncScheduleResponse(isLast: true))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.continue,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["cursor"] as? String == "next"
                },
                resultJsonString: .success(self.syncScheduleResponse(isLast: false))
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.continue,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["cursor"] as? String == "end"
                },
                resultJsonString: .success(self.syncScheduleResponse(isLast: true))
            ),
        ]
    }
    
    private var migrationNeedResponse: String {
        return """
        { "result": "migrationNeeds" }
        """
    }
    
    private var noNeedToSyncResponse: String {
        return """
        { "result": "noNeedToSync" }
        """
    }
    
    private var syncNeedResponse: String {
        return """
        { "result": "needToSync", "start": \(Int.syncNeedTimestamp) }
        """
    }
    
    private func syncTagResponse(isLast: Bool) -> String {
        let syncTime: String = !isLast ? "" : """
        "newSyncTime": {
            "userId": "some", 
            "dataType": "EventTag", 
            "timestamp": 200
        },
        """
        let cursor: String = isLast ? "" : """
        "nextPageCursor": "next", 
        """
        return """
        {  
            \(syncTime)
            \(cursor)
            "created": [
                { "uuid": "t5", "name": "new_tag5", "color_hex": "color" }, 
                { "uuid": "t6", "name": "new_tag6", "color_hex": "color" }
            ], 
            "updated": [
                { "uuid": "t3", "name": "updated_3", "color_hex": "color" }, 
                { "uuid": "t4", "name": "updated_4", "color_hex": "color" }
            ], 
            "deleted": [ "t1", "t2" ]
        }
        """
    }
        
    private func syncTodoResponse(isLast: Bool) -> String {
        let syncTime: String = !isLast ? "" : """
        "newSyncTime": {
            "userId": "some", 
            "dataType": "Todo", 
            "timestamp": 200
        },
        """
        let cursor: String = isLast ? "" : """
        "nextPageCursor": "next", 
        """
        return """
        { 
            \(syncTime)
            \(cursor) 
            "created": [
                { "uuid": "t5", "name": "new_5" }, 
                { "uuid": "t6", "name": "new_6" }
            ], 
            "updated": [
                { "uuid": "t3", "name": "updated_3" }, 
                { "uuid": "t4", "name": "updated_4" }
            ], 
            "deleted": [ "t1", "t2" ]
        }
        """
    }
    
    private func syncScheduleResponse(isLast: Bool) -> String {
        let syncTime: String = !isLast ? "" : """
        "newSyncTime": {
            "userId": "some", 
            "dataType": "Schedule", 
            "timestamp": 200
        },
        """
        let cursor: String = isLast ? "" : """
        "nextPageCursor": "next", 
        """
        return """
        { 
            \(syncTime)
            \(cursor) 
            "created": [
                { 
                    "uuid": "sc5", "name": "new_5", 
                    "event_time": { "time_type": "at", "timestamp": 123.0 } 
                }, 
                { 
                    "uuid": "sc6", "name": "new_6", 
                    "event_time": { "time_type": "at", "timestamp": 123.0 } 
                }
            ], 
            "updated": [
                { 
                    "uuid": "sc3", "name": "updated_3", 
                    "event_time": { "time_type": "at", "timestamp": 123.0 } 
                }, 
                { 
                    "uuid": "sc4", "name": "updated_4", 
                    "event_time": { "time_type": "at", "timestamp": 123.0 } 
                }
            ], 
            "deleted": [ "sc1", "sc2" ]
        }
        """
    }
}

private extension Int {
    
    static var syncNotNeedTimestamp: Int = 100
    static var syncNeedTimestamp: Int = 120
    static var syncWithMigrationNeedTimestamp: Int = 130
}
