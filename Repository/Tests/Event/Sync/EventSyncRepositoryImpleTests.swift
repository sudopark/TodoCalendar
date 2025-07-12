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

extension EventSyncRepositoryImpleTests {
    
    private func saveOldTags() async throws {
        let tags = (1...4).map { int in
            return CustomEventTag(uuid: "t\(int)", name: "old:\(int)", colorHex: "hex")
        }
        try await self.eventTagLocalStorage.updateTags(tags)
    }
    
    // sync event tags: not need to sync
    @Test func repository_syncTags_noNeedToSync() async throws {
        try await self.runTestWithOpenClose("sync_test_tag1") {
            // given
            try await self.saveOldTags()
            try await self.saveTimeStamp(.eventTag, Int.syncNotNeedTimestamp)
            let repository = self.makeRepository()
            
            // when
            let result: EventSyncResponse<CustomEventTag> = try await repository.syncIfNeed(for: .eventTag)
            
            // then
            #expect(result.result == .noNeedToSync)
            #expect(result.newSyncTime == nil)
            #expect(result.created == nil)
            #expect(result.updated == nil)
            #expect(result.deletedIds == nil)
            
            let tags = try await self.eventTagLocalStorage.loadAllTags()
            let ids = tags.map { $0.uuid }; let names = tags.map { $0.name }
            #expect(ids == ["t1", "t2", "t3", "t4"])
            #expect(names == ["old:1", "old:2", "old:3", "old:4"])
            
            let timestamp = try await self.syncTimestampLocalStorage.loadLocalTimestamp(for: .eventTag)
            #expect(timestamp == .init(.eventTag, Int.syncNotNeedTimestamp))
        }
    }
    
    // sync event tags: need sync
    @Test func repository_syncTags_needToSync() async throws {
        try await self.runTestWithOpenClose("sync_test_tag2") {
            // given
            try await self.saveOldTags()
            try await self.saveTimeStamp(.eventTag, Int.syncNeedTimestamp)
            let repository = self.makeRepository()
            
            // when
            let result: EventSyncResponse<CustomEventTag> = try await repository.syncIfNeed(for: .eventTag)
            
            // then
            #expect(result.result == .needToSync)
            #expect(result.newSyncTime?.timeStampInt == 200)
            
            #expect(result.created?.map { $0.uuid } == ["t5", "t6"])
            #expect(result.updated?.map { $0.uuid } == ["t3", "t4"])
            #expect(result.deletedIds == ["t1", "t2"])
            
            let tags = try await self.eventTagLocalStorage.loadAllTags()
            let ids = tags.map { $0.uuid }; let names = tags.map { $0.name }
            #expect(ids.sorted() == ["t3", "t4", "t5", "t6"])
            #expect(names.sorted() == ["new_tag5", "new_tag6", "updated_3", "updated_4"])
            
            let timestamp = try await self.syncTimestampLocalStorage.loadLocalTimestamp(for: .eventTag)
            #expect(timestamp == .init(.eventTag, 200))
        }
    }
    
    // sync event tags: need to migrate
    @Test func repository_syncTags_needToSyncAll() async throws {
        try await self.runTestWithOpenClose("sync_test_tag3") {
            // given
            try await self.saveOldTags()
            try await self.saveTimeStamp(.eventTag, Int.syncWithMigrationNeedTimestamp)
            let repository = self.makeRepository()
            
            // when
            let result: EventSyncResponse<CustomEventTag> = try await repository.syncIfNeed(for: .eventTag)
            
            // then
            #expect(result.result == .migrationNeeds)
            #expect(result.newSyncTime?.timeStampInt == 200)
            
            #expect(result.created == nil)
            #expect(result.updated?.map { $0.uuid } == ["t3", "t4", "t5", "t6"])
            #expect(result.deletedIds == nil)
            
            let tags = try await self.eventTagLocalStorage.loadAllTags()
            let ids = tags.map { $0.uuid }; let names = tags.map { $0.name }
            #expect(ids.sorted() == ["t1", "t2", "t3", "t4", "t5", "t6"])
            #expect(names.sorted() == ["new_tag5", "new_tag6", "old:1", "old:2", "updated_3", "updated_4"])
            
            let timestamp = try await self.syncTimestampLocalStorage.loadLocalTimestamp(for: .eventTag)
            #expect(timestamp == .init(.eventTag, 200))
        }
    }
    
    // sync all tags
}


extension EventSyncRepositoryImpleTests {
        
    // sync event todo: not need to sync
    
    // sync event todos: need sync
    
    // sync event todos: need to migrate
    
    // sync all todos
}

extension EventSyncRepositoryImpleTests {
    
    // sync event schedules: not need to sync
    
    // sync event schedules: need sync
    
    // sync event schedules: need to migrate
    
    // sync all schedules
}

private struct DummyResponse {
    
    var response: [StubRemoteAPI.Response] {
        return [
            // tags
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int == Int.syncNotNeedTimestamp
                },
                resultJsonString: .success(self.syncNotNeedTagResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int == Int.syncNeedTimestamp
                },
                resultJsonString: .success(self.syncNeedTagResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.eventTag.rawValue
                    && params["timestamp"] as? Int == Int.syncWithMigrationNeedTimestamp
                },
                resultJsonString: .success(self.syncAllTagWithMigrationResponse)
            ),
            
            // todos
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int == Int.syncNotNeedTimestamp
                },
                resultJsonString: .success(self.syncNotNeedTodoResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int == Int.syncNeedTimestamp
                },
                resultJsonString: .success(self.syncNeedTodoResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.todo.rawValue
                    && params["timestamp"] as? Int == Int.syncWithMigrationNeedTimestamp
                },
                resultJsonString: .success(self.syncAllTodoWithMigrationResponse)
            ),
            
            // schedules
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int == Int.syncNotNeedTimestamp
                },
                resultJsonString: .success(self.syncNotNeedScheduleResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameters: ["dataType": SyncDataType.schedule.rawValue],
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int == Int.syncNeedTimestamp
                },
                resultJsonString: .success(self.syncNeedScheduleResponse)
            ),
            .init(
                method: .get,
                endpoint: EventSyncEndPoints.sync,
                parameters: ["dataType": SyncDataType.schedule.rawValue],
                parameterCompare: { _, params in
                    params["dataType"] as? String == SyncDataType.schedule.rawValue
                    && params["timestamp"] as? Int == Int.syncWithMigrationNeedTimestamp
                },
                resultJsonString: .success(self.syncAllScheduleWithMigrationResponse)
            ),
        ]
    }
    
    private var syncNotNeedTagResponse: String {
        return """
        { "checkResult": "noNeedToSync" }
        """
    }
    
    private var syncNeedTagResponse: String {
        return """
        { 
            "checkResult": "needToSync", 
            "newSyncTime": {
                "userId": "some", 
                "dataType": "EventTag", 
                "timestamp": 200
            }, 
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
    
    private var syncAllTagWithMigrationResponse: String {
        return """
        { 
            "checkResult": "migrationNeeds", 
            "newSyncTime": {
                "userId": "some", 
                "dataType": "EventTag", 
                "timestamp": 200
            }, 
            "updated": [
                { "uuid": "t3", "name": "updated_3", "color_hex": "color" }, 
                { "uuid": "t4", "name": "updated_4", "color_hex": "color" },
                { "uuid": "t5", "name": "new_tag5", "color_hex": "color" }, 
                { "uuid": "t6", "name": "new_tag6", "color_hex": "color" }
            ]
        }
        """
    }
    
    private var syncNotNeedTodoResponse: String {
        return """
        { "checkResult": "noNeedToSync" }
        """
    }
    
    private var syncNeedTodoResponse: String {
        return """
        { 
            "checkResult": "needToSync", 
            "newSyncTime": {
                "userId": "some", 
                "dataType": "Todo", 
                "timestamp": 200
            }, 
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
    
    private var syncAllTodoWithMigrationResponse: String {
        return """
        { 
            "checkResult": "needToSync", 
            "newSyncTime": {
                "userId": "some", 
                "dataType": "Todo", 
                "timestamp": 200
            }, 
            "updated": [
                { "uuid": "t3", "name": "updated_3" }, 
                { "uuid": "t4", "name": "updated_4" }, 
                { "uuid": "t5", "name": "new_5" }, 
                { "uuid": "t6", "name": "new_6" }
            ], 
            "deleted": [ "t1", "t2" ]
        }
        """
    }
    
    private var syncNotNeedScheduleResponse: String {
        return """
        { "checkResult": "noNeedToSync" }
        """
    }
    
    private var syncNeedScheduleResponse: String {
        return """
        { 
            "checkResult": "needToSync", 
            "newSyncTime": {
                "userId": "some", 
                "dataType": "Schedule", 
                "timestamp": 200
            }, 
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
    
    private var syncAllScheduleWithMigrationResponse: String {
        return """
        { 
            "checkResult": "needToSync", 
            "newSyncTime": {
                "userId": "some", 
                "dataType": "Schedule", 
                "timestamp": 200
            }, 
            "updated": [
                { 
                    "uuid": "sc3", "name": "updated_3", 
                    "event_time": { "time_type": "at", "timestamp": 123.0 } 
                }, 
                { 
                    "uuid": "sc4", "name": "updated_4", 
                    "event_time": { "time_type": "at", "timestamp": 123.0 } 
                },
                { 
                    "uuid": "sc5", "name": "new_5", 
                    "event_time": { "time_type": "at", "timestamp": 123.0 } 
                }, 
                { 
                    "uuid": "sc6", "name": "new_6", 
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
