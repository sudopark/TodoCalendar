//
//  EventUploadServiceImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/6/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import SQLiteService
import Combine
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("EventUploadServiceImpleTests", .serialized)
final class EventUploadServiceImpleTests: LocalTestable {
    
    let sqliteService: SQLiteService = .init()
    private let spyRemote = PrivateStubRemote()
    
    private func makeService(
        with tasks: [EventUploadingTask],
        editTagMocking: PassthroughSubject<CustomEventTag, Never>? = nil,
        shouldFailEditTag: Bool = false
    ) async throws -> EventUploadServiceImple {
        
        self.spyRemote.editTagMocking = editTagMocking
        self.spyRemote.shouldFailEditTag = shouldFailEditTag
        
        let pendingQueueStorage = EventUploadPendingQueueLocalStorageImple(sqliteService: self.sqliteService)
        for try await task in tasks.async {
            try await pendingQueueStorage.pushTask(task)
        }
        
        let tagLocal = EventTagLocalStorageImple(sqliteService: self.sqliteService)
        try await tagLocal.updateTags([
            .init(uuid: "tag", name: "name", colorHex: "hex")
        ])
        
        let todoLocal = TodoLocalStorageImple(sqliteService: self.sqliteService)
        try await todoLocal.updateTodoEvents([
            .init(uuid: "todo", name: "name")
        ])
        
        let scheduleLocal = ScheduleEventLocalStorageImple(sqliteService: self.sqliteService)
        try await scheduleLocal.updateScheduleEvents([
            .init(uuid: "schedule", name: "name", time: .at(0))
        ])
        
        let eventDetailLocal = EventDetailDataLocalStorageImple(sqliteService: self.sqliteService)
        try await eventDetailLocal.saveDetail(.init("detail"))
        
        return EventUploadServiceImple(
            pendingQueueStorage: pendingQueueStorage,
            eventTagRemote: self.spyRemote,
            eventTagLocalStorage: tagLocal,
            todoRemote: self.spyRemote,
            todoLocalStorage: todoLocal,
            scheduleRemote: self.spyRemote,
            scheduleLocalStorage: scheduleLocal,
            eventDetailRemote: self.spyRemote,
            eventDetailLocalStorage: eventDetailLocal
        )
    }
    
    private func nextPendingUploadTask() async throws -> EventUploadingTask? {
        return try await self.sqliteService.async.run { db in
            let query = EventUploadPendingQueueTable.selectAll()
                .where { $0.uploadFailCount < 3 }
                .orderBy(isAscending: true) { $0.timestamp }
            return try db.loadOne(query)
        }
    }
    
    private func allPendingUploadTasks(withoutCountLimit: Bool = false) async throws -> [EventUploadingTask] {
        return try await self.sqliteService.async.run { db in
            
            var query = EventUploadPendingQueueTable.selectAll()
            if !withoutCountLimit {
                query = query.where { $0.uploadFailCount < 3 }
            }
            query = query.orderBy(isAscending: true) { $0.timestamp }
            return try db.load(query)
        }
    }
}


extension EventUploadServiceImpleTests {
    
    // task 추가 -> 업로드
    @Test func service_appendAndUploadTask() async throws {
        try await self.runTestWithOpenClose("upload_tc1") {
            // given
            let service = try await self.makeService(with: [])
            
            // when
            let task = EventUploadingTask(dataType: .eventTag, uuid: "tag", isRemovingTask: false)
            try await service.append(task)
            
            // then
            try await service.waitUntilUploadingEnd()
            
            let nextTask = try await self.nextPendingUploadTask()
            #expect(nextTask == nil)
            
            #expect(self.spyRemote.deleteOrUpdateIds == [
                "tag"
            ])
        }
    }
    
    // 업로딩 시작 -> 순차적으로 업로드
    @Test func service_uploadingTask_sequentially() async throws {
        try await self.runTestWithOpenClose("upload_tc2") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 0, dataType: .eventTag, uuid: "tag", isRemovingTask: false),
                .init(timestamp: 1, dataType: .todo, uuid: "todo", isRemovingTask: false),
                .init(timestamp: 2, dataType: .schedule, uuid: "schedule", isRemovingTask: false)
            ])
            
            // when
            try await service.resume()
            
            // then
            try await service.waitUntilUploadingEnd()
            
            let nextTask = try await self.nextPendingUploadTask()
            #expect(nextTask == nil)
            
            #expect(self.spyRemote.deleteOrUpdateIds == [
                "tag",
                "todo",
                "schedule"
            ])
        }
    }
    
    // 업로딩 시작중에 task 추가 -> 마지막에 업로드
    @Test func service_whenAppendTaskDuringUploading_uploadingAtLast() async throws {
        try await self.runTestWithOpenClose("upload_tc3") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 0, dataType: .eventTag, uuid: "tag", isRemovingTask: false),
                .init(timestamp: 1, dataType: .todo, uuid: "todo", isRemovingTask: false),
                .init(timestamp: 2, dataType: .schedule, uuid: "schedule", isRemovingTask: false)
            ])
            
            // when
            try await service.resume()
            try await service.append(.init(timestamp: 4, dataType: .eventTag, uuid: "tag-delete", isRemovingTask: true))
            
            // then
            try await service.waitUntilUploadingEnd()
            
            let nextTask = try await self.nextPendingUploadTask()
            #expect(nextTask == nil)
            
            #expect(self.spyRemote.deleteOrUpdateIds == [
                "tag",
                "todo",
                "schedule",
                "tag-delete",
            ])
        }
    }
    
    // 업로딩 중에 pause됨 -> 업로딩 loop 중지
    @Test func service_whenPausedDuringUploading_endUploadLoop() async throws {
        try await self.runTestWithOpenClose("upload_tc4") {
            // given
            let mocking = PassthroughSubject<CustomEventTag, Never>()
            let service = try await self.makeService(with: [
                .init(timestamp: 0, dataType: .todo, uuid: "todo", isRemovingTask: false),
                .init(timestamp: 1, dataType: .eventTag, uuid: "tag", isRemovingTask: false),
                .init(timestamp: 2, dataType: .schedule, uuid: "schedule", isRemovingTask: false)
            ], editTagMocking: mocking)
            
            // when
            try await service.resume()
            try await Task.sleep(for: .milliseconds(10))
            await service.pause()
            
            // then
            try await service.waitUntilUploadingEnd()
            
            let pendingTasks = try await self.allPendingUploadTasks()
            #expect(pendingTasks.map { $0.uuid } == [
                "schedule"
            ])
            #expect(self.spyRemote.deleteOrUpdateIds == [
                "todo"
            ])
        }
    }
    
    // 중단에 업로드 실패해도 무시하고 다음으로 넘어감
    @Test func service_whenUploadFail_skipToNext() async throws {
        try await self.runTestWithOpenClose("upload_tc5") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 0, dataType: .todo, uuid: "todo", isRemovingTask: false),
                .init(timestamp: 1, dataType: .eventTag, uuid: "tag", isRemovingTask: false),
                .init(timestamp: 2, dataType: .schedule, uuid: "schedule", isRemovingTask: false)
            ], shouldFailEditTag: true)
            
            // when
            try await service.resume()
            
            // then
            try await service.waitUntilUploadingEnd()
            
            let nextPendingTask = try await self.nextPendingUploadTask()
            #expect(nextPendingTask == nil)
            #expect(self.spyRemote.deleteOrUpdateIds == [
                "todo", "schedule"
            ])
        }
    }
    
    // 업로드 실패된 task 다시 업로딩 큐에 저장
    @Test func service_whenUploadFailTaskAndResheduleFailJob_appendPendingQueue() async throws {
        try await self.runTestWithOpenClose("upload_tc6") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 0, dataType: .todo, uuid: "todo", isRemovingTask: false),
                .init(timestamp: 1, dataType: .eventTag, uuid: "tag", isRemovingTask: false),
                .init(timestamp: 2, dataType: .schedule, uuid: "schedule", isRemovingTask: false)
            ], shouldFailEditTag: true)
            
            // when
            try await service.resume()
            try await service.waitUntilUploadingEnd()
                        
            // then
            let pendingTasks = try await self.allPendingUploadTasks(withoutCountLimit: true)
            #expect(pendingTasks.map { $0.uuid } == [
                "tag"
            ])
            let tagTask = pendingTasks.first(where: { $0.uuid == "tag" })
            #expect(tagTask?.uploadFailCount == 3)
            #expect(self.spyRemote.deleteOrUpdateIds == [
                "todo", "schedule"
            ])
        }
    }
    
    // 업로드 중지된 task도 임시 저장했다 rescheduleUploadFailedJobs시에 다시 업로딩 큐에 저장
    @Test func service_whenPauseUploading_rescheduleCanceledTask() async throws {
        try await self.runTestWithOpenClose("upload_tc7") {
            // given
            let mocking = PassthroughSubject<CustomEventTag, Never>()
            let service = try await self.makeService(with: [
                .init(timestamp: 0, dataType: .todo, uuid: "todo", isRemovingTask: false),
                .init(timestamp: 1, dataType: .eventTag, uuid: "tag", isRemovingTask: false),
                .init(timestamp: 2, dataType: .schedule, uuid: "schedule", isRemovingTask: false)
            ], editTagMocking: mocking)
            
            // when
            try await service.resume()
            try await Task.sleep(for: .milliseconds(10))
            await service.pause()
            try await service.waitUntilUploadingEnd()
            
            // then
            try await Task.sleep(for: .milliseconds(10))
            let pendingTasks = try await self.allPendingUploadTasks()
            #expect(pendingTasks.map { $0.uuid } == [
                "schedule", "tag"
            ])
            let tagTask = pendingTasks.first(where: { $0.uuid == "tag" })
            #expect(tagTask?.uploadFailCount == 1)
            #expect(self.spyRemote.deleteOrUpdateIds == [
                "todo"
            ])
        }
    }
}

extension EventUploadServiceImpleTests {
    
    // uploading task - delete tag
    @Test func service_deleteTag() async throws {
        try await self.runTestWithOpenClose("upload_tc10_tag") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .eventTag, uuid: "tag", isRemovingTask: true)
            ])
            
            // when
            try await service.resume()
            try await service.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didRemoveTagIds == ["tag"])
        }
    }
    
    // uploading task - update event tag
    @Test func service_updateTag() async throws {
        try await self.runTestWithOpenClose("upload_tc11_tag") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .eventTag, uuid: "tag", isRemovingTask: false)
            ])
            
            // when
            try await service.resume()
            try await service.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didEditTagIds == ["tag"])
        }
    }
    
    // uploading task - delete todo
    @Test func service_deleteTodo() async throws {
        try await self.runTestWithOpenClose("upload_tc12_todo") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .todo, uuid: "todo", isRemovingTask: true)
            ])
            
            // when
            try await service.resume()
            try await service.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didRemoveTodoIds == ["todo"])
        }
    }
    
    // uploading task - update todo
    @Test func service_updateTodo() async throws {
        try await self.runTestWithOpenClose("upload_tc13_todo") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .todo, uuid: "todo", isRemovingTask: false)
            ])
            
            // when
            try await service.resume()
            try await service.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didEditTodoIds == ["todo"])
        }
    }
    
    // uploading task - delete schedule
    @Test func service_deleteSchedule() async throws {
        try await self.runTestWithOpenClose("upload_tc14_sc") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .schedule, uuid: "schedule", isRemovingTask: true)
            ])
            
            // when
            try await service.resume()
            try await service.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didRemoveScheduleIds == ["schedule"])
        }
    }
    
    // uploading task - update schedule
    @Test func service_updateSchedule() async throws {
        try await self.runTestWithOpenClose("upload_tc15_sc") {
            // given
            let service = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .schedule, uuid: "schedule", isRemovingTask: false)
            ])
            
            // when
            try await service.resume()
            try await service.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didEditScheduleIds == ["schedule"])
        }
    }
    
    @Test func service_updateEventDetail() async throws {
        try await self.runTestWithOpenClose("upload_tc16_detail") {
            // given
            let servie = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .eventDetail, uuid: "detail", isRemovingTask: false)
            ])
            
            // when
            try await servie.resume()
            try await servie.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didEditEventDetailIds == ["detail"])
        }
    }
    
    @Test func service_deleteEventDetail() async throws {
        try await self.runTestWithOpenClose("upload_tc_17_detail_remove") {
            // given
            let servie = try await self.makeService(with: [
                .init(timestamp: 100, dataType: .eventDetail, uuid: "detail", isRemovingTask: true)
            ])
            
            // when
            try await servie.resume()
            try await servie.waitUntilUploadingEnd()
            
            // then
            #expect(self.spyRemote.didRemoveEventDetailIds == ["detail"])
        }
    }
}

private final class PrivateStubRemote: @unchecked Sendable {
    
    var deleteOrUpdateIds: [String] = []
    var editTagMocking: PassthroughSubject<CustomEventTag, Never>?
    var shouldFailEditTag: Bool = false
    
    var didRemoveTagIds: [String] = []
    var didEditTagIds: [String] = []
    var didRemoveTodoIds: [String] = []
    var didEditTodoIds: [String] = []
    var didRemoveScheduleIds: [String] = []
    var didEditScheduleIds: [String] = []
    var didEditEventDetailIds: [String] = []
    var didRemoveEventDetailIds: [String] = []
}

extension PrivateStubRemote: EventTagRemote {
    
    func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag {
        
        if shouldFailEditTag {
            throw RuntimeError("failed")
        }
        
        if let mocking = self.editTagMocking {
            let tag = try await mocking.values.first(where: { _ in true }).unwrap()
            self.deleteOrUpdateIds.append(tagId)
            self.didEditTagIds.append(tagId)
            return tag
        }
        self.deleteOrUpdateIds.append(tagId)
        self.didEditTagIds.append(tagId)
        return .init(uuid: tagId, name: params.name, colorHex: params.colorHex)
    }
    func deleteTag(_ tagId: String) async throws {
        self.deleteOrUpdateIds.append(tagId)
        self.didRemoveTagIds.append(tagId)
    }
    
    func makeTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag { return .init(uuid: "", name: "", colorHex: "") }
    
    func deleteTagWithAllEvents(_ tagId: String) async throws -> RemoveCustomEventTagWithEventsResult { return .init(todoIds: [], scheduleIds: []) }
    func loadAllEventTags() async throws -> [CustomEventTag] {[] }
    func loadCustomTags(_ ids: [String]) async throws -> [CustomEventTag] { [] }
}

extension PrivateStubRemote: TodoRemote {
    
    func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        self.deleteOrUpdateIds.append(eventId)
        self.didEditTodoIds.append(eventId)
        return .init(uuid: eventId, name: params.name ?? "")
    }
    
    func removeTodo(eventId: String) async throws -> RemoveTodoResult {
        self.deleteOrUpdateIds.append(eventId)
        self.didRemoveTodoIds.append(eventId)
        return .init()
    }
    
    func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        throw RuntimeError("failed")
    }
    
    
    func completeTodo(origin: TodoEvent, nextTime: EventTime?) async throws -> CompleteTodoResult {
        throw RuntimeError("failed")
    }
    
    func replaceRepeatingTodo(origin: TodoEvent, to newParams: TodoMakeParams, nextTime: EventTime?) async throws -> ReplaceRepeatingTodoEventResult {
        throw RuntimeError("failed")
    }
    
    func loadCurrentTodos() async throws -> [TodoEvent] { [] }
    
    func loadTodos(in range: Range<TimeInterval>) async throws -> [TodoEvent] { [] }
    
    func loadTodo(_ id: String) async throws -> TodoEvent {
        throw RuntimeError("failed")
    }
    
    func loadUncompletedTodosFromRemote(_ now: Date) async throws -> [TodoEvent] { [] }
    
    func loadDoneTodoEvents(_ params: DoneTodoLoadPagingParams) async throws -> [DoneTodoEvent] { [] }
    
    func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws { }
    
    func revertDoneTodo(_ doneTodoId: String) async throws -> TodoEvent {
        throw RuntimeError("failed")
    }
    
    func cancelDoneTodo(_ origin: TodoEvent, _ doneTodoId: String?) async throws -> RevertToggleTodoDoneResult {
        throw RuntimeError("failed")
    }
}

extension PrivateStubRemote: ScheduleEventRemote {
    
    func updateScheduleEvent(_ eventId: String, _ params: SchedulePutParams) async throws -> ScheduleEvent {
        self.deleteOrUpdateIds.append(eventId)
        self.didEditScheduleIds.append(eventId)
        return .init(uuid: eventId, name: params.name ?? "", time: params.time ?? .at(100))
    }
    
    func removeScheduleEvent(_ eventId: String) async throws {
        self.deleteOrUpdateIds.append(eventId)
        self.didRemoveScheduleIds.append(eventId)
    }
    
    func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        throw RuntimeError("failed")
    }
    
    func excludeRepeatingEvent(_ originEventId: String, at currentTime: EventTime, asNew params: ScheduleMakeParams) async throws -> ExcludeRepeatingEventResult {
        throw RuntimeError("failed")
    }
    
    func branchNewRepeatingEvent(_ originEventId: String, fromTime: TimeInterval, _ params: SchedulePutParams) async throws -> BranchNewRepeatingScheduleFromOriginResult {
        throw RuntimeError("failed")
    }
    
    func removeRepeatingScheduleEventTime(_ eventId: String, _ time: EventTime) async throws -> ScheduleEvent {
        throw RuntimeError("failed")
    }
    
    func loadScheduleEvents(in range: Range<TimeInterval>) async throws -> [ScheduleEvent] {
        throw RuntimeError("failed")
    }
    
    func loadScheduleEvent(_ eventId: String) async throws -> ScheduleEvent {
        throw RuntimeError("failed")
    }
}

extension PrivateStubRemote: EventDetailRemote {
    
    func loadDetail(_ id: String) async throws -> EventDetailData {
        throw RuntimeError("failed")
    }
    
    func saveDetail(_ detail: EventDetailData) async throws -> EventDetailData {
        self.deleteOrUpdateIds.append(detail.eventId)
        self.didEditEventDetailIds.append(detail.eventId)
        return detail
    }
    
    func removeDetail(_ id: String) async throws {
        self.deleteOrUpdateIds.append(id)
        self.didRemoveEventDetailIds.append(id)
    }
}
