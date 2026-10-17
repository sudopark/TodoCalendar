//
//  EventUploadPendingQueueLocalStorageImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 7/22/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import SQLiteService
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("EventUploadPendingQueueLocalStorageImpleTests", .serialized)
final class EventUploadPendingQueueLocalStorageImpleTests: LocalTestable {
    
    let sqliteService: SQLiteService = .init()
    
    private func makeStorage() -> EventUploadPendingQueueLocalStorageImple {
        return EventUploadPendingQueueLocalStorageImple(
            maxFailCount: 3,
            sqliteService: self.sqliteService
        )
    }
}


extension EventUploadPendingQueueLocalStorageImpleTests {
    
    @Test func storage_pushAndPopPendingTasks() async throws {
        try await self.runTestWithOpenClose("pending-1") {
            // given
            let storage = self.makeStorage()
            let task = EventUploadingTask(timestamp: 100, dataType: .schedule, uuid: "some", isRemovingTask: true)
            
            // when
            try await storage.pushTask(task)
            let popedTask = try await storage.popTask()
            
            // then
            #expect(popedTask?.timestamp == 100)
            #expect(popedTask?.dataType == .schedule)
            #expect(popedTask?.uuid == "some")
            #expect(popedTask?.isRemovingTask == true)
        }
    }
    
    @Test func storage_whenPushTaskWithEveryColumn_popRestoresSameValues() async throws {
        try await self.runTestWithOpenClose("pending-every-column") {
            // given
            let storage = self.makeStorage()
            let task = self.everyColumnTask

            // when
            try await storage.pushTask(task)
            let popedTask = try await storage.popTask()

            // then
            #expect(popedTask?.timestamp == 1_234.5)
            #expect(popedTask?.dataType == .eventDetail)
            #expect(popedTask?.uuid == "task-uuid-A")
            #expect(popedTask?.isRemovingTask == true)
            #expect(popedTask?.uploadFailCount == 2)
        }
    }

    private func saveTasks(
        _ storage: EventUploadPendingQueueLocalStorageImple,
        _ tasks: [EventUploadingTask]? = nil
    ) async throws {
        
        let tasks: [EventUploadingTask] = tasks ?? (0..<4).map { int in
            return .init(timestamp: TimeInterval(int), dataType: .eventTag, uuid: "id:\(int)", isRemovingTask: int % 2 == 0)
        }
        for task in tasks {
            try await storage.pushTask(task)
        }
    }
    
    @Test func storage_popEventsUntilNotExists() async throws {
        try await self.runTestWithOpenClose("pending-2") {
            // given
            let storage = self.makeStorage()
            try await self.saveTasks(storage)
            
            // when
            var tasks: [EventUploadingTask?] = []
            var task: EventUploadingTask?
            repeat {
                task = try await storage.popTask()
                tasks.append(task)
            } while task != nil
            
            // then
            let ids = tasks.map { $0?.uuid }
            #expect(ids == ["id:0", "id:1", "id:2", "id:3", nil])
        }
    }
    
    @Test func storage_whenPopTask_ignoreUploadFailCountGTE3() async throws {
        try await self.runTestWithOpenClose("pending-3") {
            // given
            let storage = self.makeStorage()
            let tasks = (0..<5).map { int in
                return EventUploadingTask(dataType: .eventTag, uuid: "id:\(int)", isRemovingTask: false)
                |> \.uploadFailCount .~ int
            }
            try await self.saveTasks(storage, tasks)
            
            // when
            var popTasks: [EventUploadingTask?] = []
            while let task = try await storage.popTask() {
                popTasks.append(task)
            }
            
            // then
            let ids = popTasks.map { $0?.uuid }
            #expect(ids == ["id:0", "id:1", "id:2"])
        }
    }
    
    @Test func storage_pushUploadFailedTasks() async throws {
        try await self.runTestWithOpenClose("pending-4") {
            // given
            let storage = self.makeStorage()
            let tasks = (0..<5).map { int in
                return EventUploadingTask(dataType: .eventTag, uuid: "id:\(int)", isRemovingTask: false)
            }
            try await storage.pushTasks(tasks)
            
            // when
            var popTasks: [EventUploadingTask?] = []
            while let task = try await storage.popTask() {
                popTasks.append(task)
            }
            
            // then
            let ids = popTasks.map { $0?.uuid }
            #expect(ids == ["id:0", "id:1", "id:2", "id:3", "id:4"])
        }
    }
    
    @Test func storage_pushTaskWithSameUuidButDifferentDataType() async throws {
        try await self.runTestWithOpenClose("pending-5") {
            // given
            let storage = self.makeStorage()
            let todoTask = EventUploadingTask(dataType: .todo, uuid: "todo", isRemovingTask: false)
            try await storage.pushTask(todoTask)
            try await Task.sleep(for: .milliseconds(10))
            let detailTask = EventUploadingTask(dataType: .eventDetail, uuid: "todo", isRemovingTask: false)
            try await storage.pushTask(detailTask)
            
            // when
            var popTasks: [EventUploadingTask?] = []
            while let task = try await storage.popTask() {
                popTasks.append(task)
            }
            
            // then
            let ids = popTasks.map { $0?.uuid }
            #expect(ids == ["todo", "todo"])
            let types = popTasks.map { $0?.dataType }
            #expect(types == [.todo, .eventDetail])
        }
    }
}


// MARK: - 변환이 컬럼을 다 채우는지

extension EventUploadPendingQueueLocalStorageImpleTests {
    
    private var everyColumnTask: EventUploadingTask {
        return EventUploadingTask(
            timestamp: 1_234.5, dataType: .eventDetail, uuid: "task-uuid-A", isRemovingTask: true
        )
        |> \.uploadFailCount .~ 2
    }
    
    @Test func uploadingTaskEntity_serialize_leavesNoColumnUnmapped() throws {
        // given
        let task = self.everyColumnTask
        
        // when
        let values = try EventUploadPendingQueueTable.serialize(entity: .init(task))
        
        // then
        let unmapped = zip(EventUploadPendingQueueTable.Columns.allCases, values)
            .filter { $0.1 == nil }
            .map { $0.0 }
        #expect(values.count == EventUploadPendingQueueTable.Columns.allCases.count)
        #expect(!values.isEmpty)
        #expect(unmapped.isEmpty)
    }
    
    @Test func legacyUploadingTaskEntity_serialize_leavesNoColumnUnmapped() throws {
        // given
        let task = self.everyColumnTask
        
        // when
        let values = try EventUploadPendingQueueTableV4.serialize(entity: .init(task))
        
        // then
        let unmapped = zip(EventUploadPendingQueueTableV4.Columns.allCases, values)
            .filter { $0.1 == nil }
            .map { $0.0 }
        #expect(values.count == EventUploadPendingQueueTableV4.Columns.allCases.count)
        #expect(!values.isEmpty)
        #expect(unmapped.isEmpty)
    }
    
    @Test func tempUploadingTaskEntity_serialize_leavesNoColumnUnmapped() throws {
        // given
        let task = self.everyColumnTask
        
        // when
        let values = try EventUploadPendingQueueTableV4TempTable.serialize(entity: .init(task))
        
        // then
        let unmapped = zip(EventUploadPendingQueueTableV4TempTable.Colunms.allCases, values)
            .filter { $0.1 == nil }
            .map { $0.0 }
        #expect(values.count == EventUploadPendingQueueTableV4TempTable.Colunms.allCases.count)
        #expect(!values.isEmpty)
        #expect(unmapped.isEmpty)
    }
}


// MARK: - 선언이 만드는 CREATE 문이 전환 전 스키마와 같은지 (DB 미사용)

extension EventUploadPendingQueueLocalStorageImpleTests {

    @Test func pendingQueueTablesCreateStatement_matchesPreMigrationSchema() throws {
        // given
        // when
        let v5Statement = EventUploadPendingQueueTableV5.createStatement
        let v4Statement = EventUploadPendingQueueTableV4.createStatement

        // then
        #expect(v5Statement == "CREATE TABLE IF NOT EXISTS event_upload_pending_queue (timestamp REAL NOT NULL, data_type TEXT NOT NULL, uuid TEXT NOT NULL, is_remove INTEGER DEFAULT 0 NOT NULL, upload_fail_count INTEGER DEFAULT 0 NOT NULL);")
        #expect(v4Statement == "CREATE TABLE IF NOT EXISTS event_upload_pending_queue (timestamp REAL NOT NULL, data_type TEXT NOT NULL, uuid TEXT UNIQUE NOT NULL, is_remove INTEGER DEFAULT 0 NOT NULL, upload_fail_count INTEGER DEFAULT 0 NOT NULL);")
    }
}
