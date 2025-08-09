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
        return EventUploadPendingQueueLocalStorageImple(sqliteService: self.sqliteService)
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
}
