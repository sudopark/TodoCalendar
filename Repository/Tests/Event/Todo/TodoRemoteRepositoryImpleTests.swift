//
//  TodoRemoteRepositoryImpleTests.swift
//  Repository
//
//  Created by sudo.park on 3/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository

private let refTime = Date().timeIntervalSince1970

class TodoRemoteRepositoryImpleTests: BaseTestCase, PublisherWaitable {
    
    private var stubRemote: StubRemoteAPI!
    private var spyTodoCache: SpyTodoLocalStorage!
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.stubRemote = .init(responses: self.reponses)
        self.spyTodoCache = .init()
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.stubRemote = nil
        self.spyTodoCache = nil
        self.cancelBag = nil
    }
    
    private func makeRepository(
        stubbing: ((SpyTodoLocalStorage, StubRemoteAPI) -> Void)? = nil
    ) -> TodoRemoteRepositoryImple {
        stubbing?(self.spyTodoCache, self.stubRemote)
        return TodoRemoteRepositoryImple(
            remote: self.stubRemote, cacheStorage: self.spyTodoCache
        )
    }
}

// MARK: - make and update

extension TodoRemoteRepositoryImpleTests {
    
    private var dummyRepeating: EventRepeating {
        return EventRepeating(
            repeatingStartTime: 300,
            repeatOption: EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!) |> \.dayOfWeeks .~ [.sunday]
        )
        |> \.repeatingEndTime .~ 400
        
    }
    
    private var dummyNotificationOption: EventNotificationTimeOption {
        return .allDay9AMBefore(seconds: 300)
    }
    
    func testRepository_makeTodo() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = TodoMakeParams()
            |> \.name .~ "todo_name"
            |> \.eventTagId .~ .custom("custom_id")
            |> \.time .~ .allDay(0..<100, secondsFromGMT: 300)
            |> \.repeating .~ pure(self.dummyRepeating)
            |> \.notificationOptions .~ [self.dummyNotificationOption]
        let todo = try await repository.makeTodoEvent(params)
        
        // then
        self.assertTodo(todo)
        XCTAssertEqual(self.spyTodoCache.didSavedTodoEvent?.uuid, "new_uuid")
    }
    
    func testRepository_updateTodo() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = TodoEditParams() |> \.eventTagId .~ .custom("some")
        let todo = try await repository.updateTodoEvent("new_uuid", params)
        
        // then
        self.assertTodo(todo)
        XCTAssertEqual(self.spyTodoCache.didUpdatedTodoEvent?.uuid, "new_uuid")
    }
    
    private func assertTodo(_ todo: TodoEvent) {
        XCTAssertEqual(todo.uuid, "new_uuid")
        XCTAssertEqual(todo.name, "todo_refreshed")
        XCTAssertEqual(todo.eventTagId, .custom("custom_id"))
        XCTAssertEqual(todo.time, .allDay(refTime+100..<refTime+200, secondsFromGMT: 300))
        XCTAssertEqual(todo.repeating?.repeatingStartTime, 300)
        XCTAssertEqual(todo.repeating?.repeatOption.compareHash, self.dummyRepeating.repeatOption.compareHash)
        XCTAssertEqual(todo.repeating?.repeatingEndTime, refTime+3600*24*100)
        XCTAssertEqual(todo.notificationOptions, [.allDay9AMBefore(seconds: 300)])
    }
}


// MARK: - complete and replace

extension TodoRemoteRepositoryImpleTests {
    
    // complete
    func testRepository_completeTodo() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.completeTodo("origin")
        
        // then
        XCTAssertEqual(result?.doneEvent.uuid, "done_id")
        XCTAssertEqual(result?.doneEvent.name, "todo_name")
        XCTAssertEqual(result?.doneEvent.originEventId, "origin")
        XCTAssertEqual(result?.doneEvent.doneTime.timeIntervalSince1970, 100)
        XCTAssertEqual(result?.doneEvent.eventTagId, .custom("custom_id"))
        XCTAssertEqual(result?.doneEvent.eventTime, .allDay(0..<100, secondsFromGMT: 300))
        XCTAssertEqual(result?.doneEvent.notificationOptions, [.allDay9AMBefore(seconds: 300)])
        guard let next = result?.nextRepeatingTodoEvent 
        else {
            XCTFail("next not exists")
            return
        }
        self.assertTodo(next)
        let params = self.stubRemote.didRequestedParams ?? [:]
        let nextTime = params["next_event_time"] as? [String: Any]
        let origin = params["origin"] as? [String: Any]
        XCTAssertNotNil(nextTime)
        XCTAssertNotNil(origin)
    }
    
    // complete 이후에 기존 todo 제거 + 신규 이벤트 저장 + 다음 이벤트 저장
    func testRepository_whenAfterCompleteTodo_updateCache() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let _ = try? await repository.completeTodo("origin")
        
        // then
        XCTAssertEqual(self.spyTodoCache.didRemoveTodoId, "origin")
        XCTAssertEqual(self.spyTodoCache.didSaveDoneTodoEvent?.uuid, "done_id")
        XCTAssertEqual(self.spyTodoCache.didUpdatedTodoEvent != nil, true)
    }
    
    // replace
    func testRepository_replaceRepeatingTodo() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.replaceRepeatingTodo(current: "origin", to: .init())
        
        // then
        guard let new = result?.newTodoEvent, let next = result?.newTodoEvent
        else {
            XCTFail("new or next not exists")
            return
        }
        self.assertTodo(new)
        self.assertTodo(next)
        let params = self.stubRemote.didRequestedParams ?? [:]
        let nextTime = params["origin_next_event_time"] as? [String: Any]
        let newPayload = params["new"] as? [String: Any]
        XCTAssertNotNil(nextTime)
        XCTAssertNotNil(newPayload)
    }
    
    // replace 이후에 기존 todo 제거, 신규 todo 저장, 다음 이벤트 저장
    func testRepository_whenAfterReplaceRepeatingTodo_updateCache() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let _ = try? await repository.replaceRepeatingTodo(current: "origin", to: .init())
        
        // then
        XCTAssertEqual(self.spyTodoCache.didRemoveTodoId, "origin")
        XCTAssertEqual(self.spyTodoCache.didSavedTodoEvent != nil, true)
        XCTAssertEqual(self.spyTodoCache.didUpdatedTodoEvent != nil, true)
    }
}

// TOOD: remove

extension TodoRemoteRepositoryImpleTests {
    
    // 이벤트 삭제
    func testRepository_removeTodo() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.removeTodo("repeating-todo", onlyThisTime: false)
        
        // then
        XCTAssertNotNil(result)
        XCTAssertNil(result?.nextRepeatingTodo)
        XCTAssertEqual(self.spyTodoCache.didRemoveTodoId, "repeating-todo")
    }
    
    // 반복 이벤트 이번만 삭제시 다음 이벤트 있으면 이벤트 시간 다음으로 업데이트
    func testRepository_whenRemoveRepeatingTodoOnlyThisTime_updateNextEventTime() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.removeTodo("repeating-todo", onlyThisTime: true)
        
        // then
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.nextRepeatingTodo)
        XCTAssertEqual(self.spyTodoCache.didRemoveTodoId, nil)
        XCTAssertEqual(self.spyTodoCache.didUpdatedTodoEvent?.uuid, result?.nextRepeatingTodo?.uuid)
    }
    
    // 반복 이벤트 이번만 삭제시 다음 이벤트 없으면 그냥 삭제만
    func testRepository_whenRemoveRepeatingTodoAndHasNoNextOnlyThistime_justRemove() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.removeTodo("no-next-repeating-todo", onlyThisTime: true)
        
        // then
        XCTAssertNotNil(result)
        XCTAssertNil(result?.nextRepeatingTodo)
        XCTAssertEqual(self.spyTodoCache.didRemoveTodoId, "no-next-repeating-todo")
    }
    
    // 반복 안하는 이벤트 이번만 삭제 요청시 다음 이벤트 시간 없으니 그냥 삭제
    func testRepository_whenRemoveNotRepeatingTodoOnlyThistime_justRemove() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.removeTodo("not-repeating-todo", onlyThisTime: true)
        
        // then
        XCTAssertNotNil(result)
        XCTAssertNil(result?.nextRepeatingTodo)
        XCTAssertEqual(self.spyTodoCache.didRemoveTodoId, "not-repeating-todo")
    }
}

// MARK: - load

extension TodoRemoteRepositoryImpleTests {
    
    // load current todos
    func testRepository_whenLoadCurrentTodo_loadCacheAndRemote() {
        // given
        let expect = expectation(description: "load current todos")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.loadCurrentTodoEvents()
        let todoLists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let idLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(idLists, [
            ["new_uuid", "should_removed"],
            ["new_uuid"]
        ])
    }
    
    // after load current todos updated cached + remove not exists at refreshed
    func testRepository_whenAfterLoadCurrentTodo_replaceCache() {
        // given
        let expect = expectation(description: "remove and update cache")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        self.spyTodoCache.didUpdateTodosCallback = { expect.fulfill() }
        self.spyTodoCache.didTodosRemovedCallback = { expect.fulfill() }
        
        // when
        repository.loadCurrentTodoEvents()
            .sink(receiveValue: { _ in })
            .store(in: &self.cancelBag)
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodos?.map { $0.name },
            ["todo_refreshed"]
        )
        XCTAssertEqual(
            self.spyTodoCache.didRemovedTodoIds,
            ["new_uuid", "should_removed"]
        )
    }
    
    // load current todos when load cached failed + ignore cache
    func testRepository_whenLoadCurrentTodoAndLoadCacheFail_ignore() {
        // given
        let expect = expectation(description: "load current todos when load cached failed + ignore cache")
        let repository = self.makeRepository { 
            cache, _ in cache.shouldLoadCurrentTodoFail = true
        }
        
        // when
        let loading = repository.loadCurrentTodoEvents()
        let todoLists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let nameLists = todoLists.map { ts in ts.map { $0.name } }
        XCTAssertEqual(nameLists, [
            ["todo_refreshed"]
        ])
    }
    
    // load current todos when load remote failed + faild
    func testRepository_whenLoadCurrentTodoAndLoadFromRemoteFail_shouldFail() {
        // given
        let expect = expectation(description: "load current todos when load remote failed + faild")
        let repository = self.makeRepository { _, remote in
            remote.shouldFailRequest = true
        }
        
        // when
        let loading = repository.loadCurrentTodoEvents()
        let error = self.waitError(expect, for: loading)
        
        // then
        XCTAssertNotNil(error)
    }
    
    // load todos
    func testRepository_whenLoadTodosInRange_loadCacheAndRemote() {
        // given
        let expect = expectation(description: "load todos")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.loadTodoEvents(in: 0..<100)
        let todoLists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let idLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(idLists, [
            ["new_uuid", "should_removed"],
            ["new_uuid"]
        ])
    }
    
    // after load todos updated cached + remove not exists at refreshed
    func testRepository_whenAfterLoadTodosInRange_replaceCache() {
        // given
        let expect = expectation(description: "remove and update cache")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        self.spyTodoCache.didUpdateTodosCallback = { expect.fulfill() }
        self.spyTodoCache.didTodosRemovedCallback = { expect.fulfill() }
        
        // when
        repository.loadTodoEvents(in: 0..<100)
            .sink(receiveValue: { _ in })
            .store(in: &self.cancelBag)
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodos?.map { $0.name },
            ["todo_refreshed"]
        )
        XCTAssertEqual(
            self.spyTodoCache.didRemovedTodoIds,
            ["new_uuid", "should_removed"]
        )
    }
    
    // load todos when load cached failed + ignore cache
    func testRepository_whenLoadTodosInRangeAndLoadCacheFail_ignore() {
        // given
        let expect = expectation(description: "load todos when load cached failed + ignore cache")
        let repository = self.makeRepository {
            cache, _ in cache.shouldFailLoadTodosInRange = true
        }
        
        // when
        let loading = repository.loadTodoEvents(in: 0..<100)
        let todoLists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let nameLists = todoLists.map { ts in ts.map { $0.name } }
        XCTAssertEqual(nameLists, [
            ["todo_refreshed"]
        ])
    }
    
    // load todos when load remote failed + faild
    func testRepository_whenLoadTodosInRangeAndLoadFromRemoteFail_shouldFail() {
        // given
        let expect = expectation(description: "load todos when load remote failed + faild")
        let repository = self.makeRepository { _, remote in
            remote.shouldFailRequest = true
        }
        
        // when
        let loading = repository.loadTodoEvents(in: 0..<100)
        let error = self.waitError(expect, for: loading)
        
        // then
        XCTAssertNotNil(error)
    }
    
    // load todo
    func testRepository_whenLoadTodos_loadCacheAndRemote() {
        // given
        let expect = expectation(description: "load todo")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.todoEvent("origin")
        let todos = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let names = todos.map { $0.name }
        XCTAssertEqual(names, [ "cached", "todo_refreshed"])
    }
    
    // after load todo updated cached + remove not exists at refreshed
    func testRepository_whenAfterLoadTodo_replaceCache() {
        // given
        let expect = expectation(description: "remove and update cache")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        self.spyTodoCache.didUpdateTodosCallback = { expect.fulfill() }
        self.spyTodoCache.didTodosRemovedCallback = { expect.fulfill() }
        
        // when
        repository.todoEvent("origin")
            .sink(receiveValue: { _ in })
            .store(in: &self.cancelBag)
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodos?.map { $0.name },
            ["todo_refreshed"]
        )
        XCTAssertEqual(
            self.spyTodoCache.didRemovedTodoIds,
            ["origin"]
        )
    }
    
    // load todo when load cached failed + ignore cache
    func testRepository_whenLoadTodoAndLoadCacheFail_ignore() {
        // given
        let expect = expectation(description: "load todo when load cached failed + ignore cache")
        let repository = self.makeRepository {
            cache, _ in cache.shouldFailLoadTodo = true
        }
        
        // when
        let loading = repository.todoEvent("origin")
        let todos = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let nameLists = todos.map { $0.name }
        XCTAssertEqual(nameLists, ["todo_refreshed"])
    }
    
    // load todo when load remote failed + faild
    func testRepository_whenLoadTodosAndLoadFromRemoteFail_shouldFail() {
        // given
        let expect = expectation(description: "load todo when load remote failed + faild")
        let repository = self.makeRepository { _, remote in
            remote.shouldFailRequest = true
        }
        
        // when
        let loading = repository.todoEvent("origin")
        let error = self.waitError(expect, for: loading)
        
        // then
        XCTAssertNotNil(error)
    }
}
 

private extension TodoRemoteRepositoryImpleTests {
    
    private var dummySingleTodoResponse: String {
        return """
        {
            "uuid": "new_uuid",
            "name": "todo_refreshed",
            "event_tag_id": "custom_id",
            "event_time": {
                "time_type": "allday",
                "period_start": \(refTime+100),
                "period_end": \(refTime+200),
                "seconds_from_gmt": 300
            },
            "repeating": {
                "start": 300,
                "end": \(refTime+3600*24*100),
                "option": {

                    "optionType": "every_week",
                    "interval": 1,
                    "dayOfWeek": [1],
                    "timeZone": "Asia/Seoul"
                }
            },
            "notification_options": [
                {
                    "type_text": "allDay9AMBefore",
                    "before_seconds": 300
                }
            ]
        }
        """
    }
    
    private var dummyDoneTodoResponse: String {
        return """
        {
            "uuid": "done_id",
            "name": "todo_name",
            "event_tag_id": "custom_id",
            "origin_event_id": "origin",
            "done_at": 100,
            "event_time": {
                "time_type": "allday",
                "period_start": 0,
                "period_end": 100,
                "seconds_from_gmt": 300
            },
            "notification_options": [
                {
                    "type_text": "allDay9AMBefore",
                    "before_seconds": 300
                }
            ]
        }
        """
    }
    
    private var dummyNoRepeatingTodoResponse: String {
        return """
        {
            "uuid": "new_uuid",
            "name": "todo_name",
            "event_tag_id": "custom_id"
        }
        """
    }
    
    private var dummyNoNextRepeatingTimeTodoResponse: String {
        return """
        {
            "uuid": "new_uuid",
            "name": "todo_name",
            "event_tag_id": "custom_id",
            "event_time": {
                "time_type": "allday",
                "period_start": \(refTime+100),
                "period_end": \(refTime+200),
                "seconds_from_gmt": 300
            },
            "repeating": {
                "start": 300,
                "end": \(refTime+201),
                "option": {

                    "optionType": "every_week",
                    "interval": 1,
                    "dayOfWeek": [1],
                    "timeZone": "Asia/Seoul"
                }
            }
        }
        """
    }
    
    private var reponses: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("origin"),
                resultJsonString: .success(self.dummySingleTodoResponse)
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("repeating-todo"),
                resultJsonString: .success(self.dummySingleTodoResponse)
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("not-repeating-todo"),
                resultJsonString: .success(self.dummyNoRepeatingTodoResponse)
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("no-next-repeating-todo"),
                resultJsonString: .success(self.dummyNoNextRepeatingTimeTodoResponse)
            ),
            .init(
                method:.post,
                endpoint: TodoAPIEndpoints.make,
                resultJsonString: .success(self.dummySingleTodoResponse)
            ),
            .init(
                method: .put,
                endpoint: TodoAPIEndpoints.todo("new_uuid"),
                resultJsonString: .success(self.dummySingleTodoResponse)
            ),
            .init(
                method: .patch,
                endpoint: TodoAPIEndpoints.todo("repeating-todo"),
                resultJsonString: .success(self.dummySingleTodoResponse)
            ),
            .init(
                method: .post,
                endpoint: TodoAPIEndpoints.done("origin"),
                resultJsonString: .success(
                """
                {
                    "done": \(self.dummyDoneTodoResponse),
                    "next_repeating": \(self.dummySingleTodoResponse)
                }
                """
                )
            ),
            .init(
                method: .post,
                endpoint: TodoAPIEndpoints.replaceRepeating("origin"),
                resultJsonString: .success(
                """
                {
                    "new_todo": \(self.dummySingleTodoResponse),
                    "next_repeating": \(self.dummySingleTodoResponse)
                }
                """
                )
            ),
            .init(
                method: .delete,
                endpoint: TodoAPIEndpoints.todo("repeating-todo"),
                resultJsonString: .success("{ \"status\": \"ok\" }")
            ),
            .init(
                method: .delete,
                endpoint: TodoAPIEndpoints.todo("not-repeating-todo"),
                resultJsonString: .success("{ \"status\": \"ok\" }")
            ),
            .init(
                method: .delete,
                endpoint: TodoAPIEndpoints.todo("no-next-repeating-todo"),
                resultJsonString: .success("{ \"status\": \"ok\" }")
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.currentTodo,
                resultJsonString: .success(
                    """
                    [ \(self.dummySingleTodoResponse) ]
                    """
                )
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todos,
                resultJsonString: .success(
                    """
                    [ \(self.dummySingleTodoResponse) ]
                    """
                )
            )
        ]
    }
}


private class SpyTodoLocalStorage: TodoLocalStorage, @unchecked Sendable {
    
    func loadAllEvents() async throws -> [TodoEvent] {
        return []
    }
    func loadAllDoneEvents() async throws -> [DoneTodoEvent] {
        return []
    }
    
    var shouldFailLoadTodo: Bool = false
    func loadTodoEvent(_ eventId: String) async throws -> TodoEvent {
        guard self.shouldFailLoadTodo == false
        else {
            throw RuntimeError("failed")
        }
        let todo = TodoEvent(uuid: eventId, name: "cached")
        return todo
    }
    
    var shouldLoadCurrentTodoFail: Bool = false
    func loadCurrentTodoEvents() async throws -> [TodoEvent] {
        guard self.shouldLoadCurrentTodoFail == false
        else {
            throw RuntimeError("failed")
        }
        let todo = TodoEvent(uuid: "new_uuid", name: "cached")
        let shouldRemoveTodo = TodoEvent(uuid: "should_removed", name: "some")
        return [todo, shouldRemoveTodo]
    }
    
    var shouldFailLoadTodosInRange: Bool = false
    func loadTodoEvents(in range: Range<TimeInterval>) async throws -> [TodoEvent] {
        guard self.shouldFailLoadTodosInRange == false
        else {
            throw RuntimeError("shouldFailLoadTodosInRange")
        }
        let todo = TodoEvent(uuid: "new_uuid", name: "cached")
        let shouldRemoveTodo = TodoEvent(uuid: "should_removed", name: "some")
        return [todo, shouldRemoveTodo]
    }
    
    var didSavedTodoEvent: TodoEvent?
    func saveTodoEvent(_ todo: TodoEvent) async throws {
        self.didSavedTodoEvent = todo
    }
    
    var didUpdatedTodoEvent: TodoEvent?
    func updateTodoEvent(_ todo: TodoEvent) async throws {
        self.didUpdatedTodoEvent = todo
    }
    
    var didUpdatedTodos: [TodoEvent]?
    var didUpdateTodosCallback: (() -> Void)?
    func updateTodoEvents(_ todos: [TodoEvent]) async throws {
        self.didUpdatedTodos = todos
        self.didUpdateTodosCallback?()
    }
    
    var didSaveDoneTodoEvent: DoneTodoEvent?
    func saveDoneTodoEvent(_ doneEvent: DoneTodoEvent) async throws {
        self.didSaveDoneTodoEvent = doneEvent
    }
    
    var didRemoveTodoId: String?
    func removeTodo(_ eventId: String) async throws {
        self.didRemoveTodoId = eventId
    }
    
    var didRemovedTodoIds: [String]?
    var didTodosRemovedCallback: (() -> Void)?
    func removeTodos(_ eventids: [String]) async throws {
        self.didRemovedTodoIds = eventids
        self.didTodosRemovedCallback?()
    }
    
    var didRemoveAll: Bool?
    func removeAll() async throws {
        self.didRemoveAll = true
    }
    
    func removeAllDoneEvents() async throws { }
}
