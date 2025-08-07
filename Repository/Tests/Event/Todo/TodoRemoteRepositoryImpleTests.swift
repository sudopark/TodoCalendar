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

class TodoRemoteRepositoryImpleTests: BaseTestCase, PublisherWaitable {
    
    private var stubRemote: StubRemoteAPI!
    private var spyTodoCache: SpyTodoLocalStorage!
    private var dummyResponse: DummyResponse!
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.dummyResponse = .init()
        self.stubRemote = .init(responses: self.dummyResponse.reponses)
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
        let remote = TodoRemoteImple(remote: self.stubRemote)
        return TodoRemoteRepositoryImple(
            remote: remote, cacheStorage: self.spyTodoCache
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
        |> \.repeatingEndOption .~ .until(400)
        
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
        let params = TodoEditParams(.put) |> \.eventTagId .~ .custom("some")
        let todo = try await repository.updateTodoEvent("new_uuid", params)
        
        // then
        self.assertTodo(todo)
        XCTAssertEqual(self.spyTodoCache.didUpdatedTodoEvent?.uuid, "new_uuid")
    }
    
    func testRepository_updateTodoWithPatch() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = TodoEditParams(.patch) |> \.name .~ "new"
        let todo = try await repository.updateTodoEvent("repeating-todo", params)
        
        // then
        self.assertTodo(todo, uuid: "repeating-todo")
        XCTAssertEqual(self.spyTodoCache.didUpdatedTodoEvent?.uuid, "repeating-todo")
    }
    
    private func assertTodo(_ todo: TodoEvent, uuid: String = "new_uuid") {
        let refTime = self.dummyResponse.refTime
        XCTAssertEqual(todo.uuid, uuid)
        XCTAssertEqual(todo.name, "todo_refreshed")
        XCTAssertEqual(todo.eventTagId, .custom("custom_id"))
        XCTAssertEqual(todo.time, .allDay(refTime+100..<refTime+200, secondsFromGMT: 300))
        XCTAssertEqual(todo.repeating?.repeatingStartTime, 300)
        XCTAssertEqual(todo.repeating?.repeatOption.compareHash, self.dummyRepeating.repeatOption.compareHash)
        XCTAssertEqual(todo.repeating?.repeatingEndOption?.endTime, refTime+3600*24*100)
        XCTAssertEqual(todo.notificationOptions, [.allDay9AMBefore(seconds: 300)])
        XCTAssertEqual(todo.creatTimeStamp, 100)
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

extension TodoRemoteRepositoryImpleTests {
    
    // load done todos
    func testRepository_loadDoneTodos() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let dones = try await repository.loadDoneTodoEvents(.init(cursorAfter: nil, size: 100))
        
        // then
        XCTAssertEqual(dones.map { $0.uuid }, ["done_id"])
        XCTAssertEqual(self.spyTodoCache.didUpdatedDoneTodos?.map { $0.uuid }, ["done_id"])
    }
    
    // load done todos fail
    func testRepository_loadDoneTodosFail() async throws {
        // given
        let repository = self.makeRepository { _, remote in
            remote.shouldFailRequest = true
        }
        var failed: Error?
        
        // when
        do {
            let  _ = try await repository.loadDoneTodoEvents(.init(cursorAfter: nil, size: 100))
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    // remvoe done todos
    func testRepository_removeDoneTodosWithRange() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        try await repository.removeDoneTodos(.pastThan(3))
        
        // then
        XCTAssertEqual(self.stubRemote.didRequestedParams?["past_than"] as? Double, 3)
        XCTAssertEqual(self.spyTodoCache.didRemovedDoneTodoCursor, 3)
    }
    
    func testReposiotry_removeAllDoneTodoEvents() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        try await repository.removeDoneTodos(.all)
        
        // then
        XCTAssertEqual(self.stubRemote.didRequestedParams?["past_than"] as? Double, nil)
        XCTAssertEqual(self.spyTodoCache.didRemoveAllDoneEvents, true)
    }
    
    // revert done todo
    func testRepository_revertDoneTodo() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let reverted = try await repository.revertDoneTodo("some")
        
        // then
        XCTAssertEqual(self.spyTodoCache.didUpdatedTodoEvent?.uuid, reverted.uuid)
        XCTAssertEqual(self.spyTodoCache.didRemovedDoneTodoIds, ["some"])
    }
    
    // revert 할꺼면 done = "some" 이여야하고
    // complete 처리할꺼면 = :origin
    
    private func makeRepositoryWithUpdateToggleState(
        _ id: String,
        _ newValue: TodoToggleStateUpdateParamas?
    ) async throws -> TodoRemoteRepositoryImple {
        let repository = self.makeRepository()
        try await self.spyTodoCache.updateTodoToggleState(id, newValue ?? .idle)
        return repository
    }
    
    // toggle -> 완료
    func testRepository_whenToggleTodoisNoneAndToggleRequested_completeTodo() async throws {
        // given
        let todoId = "origin"
        let repository = self.makeRepository()
        
        // when
        let result = try await repository.toggleTodo(todoId)
        
        // then
        XCTAssertEqual(result?.isCompleted, true)
        XCTAssertEqual(self.spyTodoCache.stubToggleStateMap[todoId]?.isIdle, true)
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodoToggleStatesMap[todoId]?.map { $0.recordedState },
            [.completing, .idle]
        )
    }
    
    func testRepository_whenToggleTodoisIdleAndToggleRequested_completeTodo() async throws {
        // given
        let todoId = "origin"
        let repository = try await self.makeRepositoryWithUpdateToggleState(todoId, .idle)
        
        // when
        let result = try await repository.toggleTodo(todoId)
        
        // then
        XCTAssertEqual(result?.isCompleted, true)
        XCTAssertEqual(self.spyTodoCache.stubToggleStateMap[todoId]?.isIdle, true)
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodoToggleStatesMap[todoId]?.map { $0.recordedState },
            [.idle, .completing, .idle]
        )
    }

    // toggle -> 완료 실패시에 상태 다시 idle로 변경
    func testRepository_whenToggleTodoisIdleAndToggleRequestedFailed_stateIsIdle() async throws {
        // given
        let todoId = "complete_fail"
        let repository = try await self.makeRepositoryWithUpdateToggleState(todoId, .idle)
        
        // when
        let result = try? await repository.toggleTodo(todoId)
        
        // then
        XCTAssertNil(result)
        XCTAssertEqual(self.spyTodoCache.stubToggleStateMap[todoId]?.isIdle, true)
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodoToggleStatesMap[todoId]?.map { $0.recordedState },
            [.idle, .completing, .idle]
        )
    }
    
    // toggle -> 완료중일때는 revert
    func testRepository_whenToggleTodoIsCompletingAndToggleRequested_revertToggle() async throws {
        // given
        let todoId = "origin"
        let repository = try await self.makeRepositoryWithUpdateToggleState(
            todoId, .completing(origin: TodoEvent(uuid: todoId, name: "origin"))
        )
        
        // when
        let result = try await repository.toggleTodo(todoId)
        
        // then
        XCTAssertEqual(result?.isReverted, true)
        XCTAssertEqual(self.spyTodoCache.stubToggleStateMap[todoId]?.isIdle, true)
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodoToggleStatesMap[todoId]?.map { $0.recordedState },
            [.completing, .reverting, .idle]
        )
    }
    
    // toggle -> reverting시에는 아무것도 안함
    func testRepository_whenToggleTodoIsRevertingAndToggleRequested_doNothing() async throws {
        // given
        let todoId = "origin"
        let repository = try await self.makeRepositoryWithUpdateToggleState(
            todoId, .reverting
        )
        
        // when
        let result = try await repository.toggleTodo(todoId)
        
        // then
        XCTAssertNil(result)
        XCTAssertEqual(self.spyTodoCache.stubToggleStateMap[todoId]?.isReverting, true)
        XCTAssertEqual(
            self.spyTodoCache.didUpdatedTodoToggleStatesMap[todoId]?.map { $0.recordedState },
            [.reverting]
        )
    }
}


// MARK: - swift testing

import Testing

@Suite("TodoRemoteRepositoryImpleTestsV2", .serialized)
class TodoRemoteRepositoryImpleTestsV2: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private let stubRemote: StubRemoteAPI
    private let spyTodoCache: SpyTodoLocalStorage
    
    init() {
        self.stubRemote = .init(responses: DummyResponse().reponses)
        self.spyTodoCache = .init()
    }
    
    private func makeRepository(
        stubbing: ((SpyTodoLocalStorage, StubRemoteAPI) -> Void)? = nil
    ) -> TodoRemoteRepositoryImple {
        stubbing?(self.spyTodoCache, self.stubRemote)
        let remote = TodoRemoteImple(remote: self.stubRemote)
        return TodoRemoteRepositoryImple(remote: remote, cacheStorage: self.spyTodoCache)
    }
}

extension TodoRemoteRepositoryImpleTestsV2 {
    
    @Test func repository_loadUncompletedTodos_withCachedAndRemote() async throws {
        // given
        let expect = expectConfirm("load uncompleted todos")
        expect.count = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.loadUncompletedTodos()
        let todoLists = try await self.outputs(expect, for: loading)
        
        // then
        let requestedRefTime = self.stubRemote.didRequestedParams?["refTime"] as? TimeInterval
        #expect(requestedRefTime != nil)
        let nameLists = todoLists.map { ts in ts.map { $0.name } }
        #expect(nameLists == [
            (0..<10).map { "cached_todo:\($0)" },
            (0..<10).map { "todo_refreshed:\($0)" }
        ])
    }
    
    @Test func repository_whenLoadUncompletedTodos_refreshCached() async throws {
        // given
        let expect = expectConfirm("load uncompleted todos and refresh cached")
        expect.count = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.loadUncompletedTodos()
        let _ = try await self.outputs(expect, for: loading)
        
        // then
        let updateds = self.spyTodoCache.didUpdatedTodos
        let updatedNames = updateds?.map { $0.name }
        #expect(updatedNames == (0..<10).map { "todo_refreshed:\($0)" })
    }
    
    @Test func repository_whenLoadUncompletedTodosAndLoadCachFail_ignore() async throws {
        // given
        let expect = expectConfirm("load uncompleted todos and load from cache fails ignore")
        let repository = self.makeRepository { cache, _ in
            cache.shouldFailLoadUncompleted = true
        }
        
        // when
        let loading = repository.loadUncompletedTodos()
        let todoLists = try await self.outputs(expect, for: loading)
        
        // then
        let nameLists = todoLists.map { ts in ts.map { $0.name } }
        #expect(nameLists == [
            (0..<10).map { "todo_refreshed:\($0)" }
        ])
    }
}


extension TodoRemoteRepositoryImpleTestsV2 {
    
    @Test func repository_skipRepeatingTodo() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let next = try await repository.skipRepeatingTodo("repeating")
        
        // then
        let params = self.stubRemote.didRequestedParams ?? [:]
        let timeParams = params["event_time"] as? [String: Any]
        #expect(params.count == 1)
        #expect(timeParams != nil)
        #expect(next != nil)
    }
    
    @Test func repository_whenSkipNotRepeatingTodo_error() async throws {
        // given
        let repository = self.makeRepository()
        var reason: (any Error)?
        // when
        do {
            let _ = try await repository.skipRepeatingTodo("not_repeating")
        } catch let err {
            reason = err
        }
        
        // then
        let runtimeError = (reason as? RuntimeError)
        #expect(runtimeError?.key == ClientErrorKeys.notARepeatingEvent.rawValue)
    }
    
    @Test func repository_whenSkipLastRepeatingTodo_error() async throws {
        // given
        let repository = self.makeRepository()
        var reason: (any Error)?
        // when
        do {
            let _ = try await repository.skipRepeatingTodo("last_repeating")
        } catch let err {
            reason = err
        }
        
        // then
        let runtimeError = (reason as? RuntimeError)
        #expect(runtimeError?.key == ClientErrorKeys.repeatingIsEnd.rawValue)
    }
}

private struct DummyResponse {
    
    let refTime = Date().timeIntervalSince1970
    
    private func dummySingleTodoResponse(_ uuid: String = "new_uuid") -> String {
        return """
        {
            "uuid": "\(uuid)",
            "name": "todo_refreshed",
            "create_timestamp": 100,
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
    
    private var dummyNotRepeatingTodo: String {
        return """
        {
            "uuid": "not_repeating",
            "name": "todo_refreshed",
            "create_timestamp": 100,
            "event_tag_id": "custom_id",
            "event_time": {
                "time_type": "allday",
                "period_start": \(refTime+100),
                "period_end": \(refTime+200),
                "seconds_from_gmt": 300
            }
        }
        """
    }
    
    private var dummyLastRepeatingTodo: String {
        return """
        {
            "uuid": "last_repeating",
            "name": "todo_refreshed",
            "create_timestamp": 100,
            "event_tag_id": "custom_id",
            "event_time": {
                "time_type": "allday",
                "period_start": \(refTime+100),
                "period_end": \(refTime+200),
                "seconds_from_gmt": 300
            }, 
            "repeating": {
                "start": 300,
                "end": \(refTime+300),
                "option": {

                    "optionType": "every_week",
                    "interval": 1,
                    "dayOfWeek": [1],
                    "timeZone": "Asia/Seoul"
                }
            },
        }
        """
    }
    
    private func dummyUncompletedTodoRespons(_ int: Int) -> String {
        return """
        {
            "uuid": "todo:\(int)",
            "name": "todo_refreshed:\(int)",
            "create_timestamp": 100,
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
            "event_tag_id": "custom_id",
            "create_timestamp": 100
        }
        """
    }
    
    private var dummyNoNextRepeatingTimeTodoResponse: String {
        return """
        {
            "uuid": "new_uuid",
            "name": "todo_name",
            "create_timestamp": 100,
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
    
    var reponses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("origin"),
                resultJsonString: .success(self.dummySingleTodoResponse("origin"))
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("complete_fail"),
                resultJsonString: .success(self.dummySingleTodoResponse("complete_fail"))
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("repeating-todo"),
                resultJsonString: .success(self.dummySingleTodoResponse("repeating-todo"))
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
                resultJsonString: .success(self.dummySingleTodoResponse())
            ),
            .init(
                method: .put,
                endpoint: TodoAPIEndpoints.todo("new_uuid"),
                resultJsonString: .success(self.dummySingleTodoResponse())
            ),
            .init(
                method: .patch,
                endpoint: TodoAPIEndpoints.todo("repeating-todo"),
                resultJsonString: .success(self.dummySingleTodoResponse("repeating-todo"))
            ),
            .init(
                method: .post,
                endpoint: TodoAPIEndpoints.done("origin"),
                resultJsonString: .success(
                """
                {
                    "done": \(self.dummyDoneTodoResponse),
                    "next_repeating": \(self.dummySingleTodoResponse())
                }
                """
                )
            ),
            .init(
                method: .post,
                endpoint: TodoAPIEndpoints.done("complete_fail"),
                resultJsonString: .failure(RuntimeError("failed"))
            ),
            .init(
                method: .post,
                endpoint: TodoAPIEndpoints.replaceRepeating("origin"),
                resultJsonString: .success(
                """
                {
                    "new_todo": \(self.dummySingleTodoResponse()),
                    "next_repeating": \(self.dummySingleTodoResponse())
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
                    [ \(self.dummySingleTodoResponse()) ]
                    """
                )
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todos,
                resultJsonString: .success(
                    """
                    [ \(self.dummySingleTodoResponse()) ]
                    """
                )
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.uncompleteds,
                resultJsonString: .success(
                    """
                    [ \((0..<10).map { self.dummyUncompletedTodoRespons($0) }.joined(separator: ",")) ]
                    """
                )
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.dones,
                resultJsonString: .success(
                    """
                    [ \(self.dummyDoneTodoResponse) ]
                    """
                )
            ),
            .init(
                method: .delete,
                endpoint: TodoAPIEndpoints.dones,
                resultJsonString: .success("{ \"status\": \"ok\" }")
            ),
            .init(
                method: .post,
                endpoint: TodoAPIEndpoints.revertDone("some"),
                resultJsonString: .success(self.dummySingleTodoResponse())
            ),
            .init(
                method: .post,
                endpoint: TodoAPIEndpoints.cancelDone,
                resultJsonString: .success(
                    "{ \"reverted\": \(self.dummySingleTodoResponse()), \"deleted_done_id\": \"some_done\" }"
                )
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("repeating"),
                resultJsonString: .success(self.dummySingleTodoResponse("repeating"))
            ),
            .init(
                method: .patch,
                endpoint: TodoAPIEndpoints.todo("repeating"),
                resultJsonString: .success(self.dummySingleTodoResponse(("repeating")))
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("not_repeating"),
                resultJsonString: .success(self.dummyNotRepeatingTodo)
            ),
            .init(
                method: .get,
                endpoint: TodoAPIEndpoints.todo("last_repeating"),
                resultJsonString: .success(self.dummyLastRepeatingTodo)
            ),
        ]
    }
}


private extension TodoToggleResult {
    
    var isCompleted: Bool {
        guard case .completed = self else { return false }
        return true
    }
    
    var isReverted: Bool {
        guard case .reverted = self else { return false }
        return true
    }
}

private extension TodoTogglingState {
    
    var isIdle: Bool {
        guard case .idle = self else { return false }
        return true
    }
    
    var isCompleting: Bool {
        guard case .completing = self else { return false }
        return true
    }
    
    var completedDoneId: String? {
        guard case .completing(_, let doneId) = self else { return nil }
        return doneId
    }
    
    var isReverting: Bool {
        guard case .reverting = self else { return false }
        return true
    }
}

private extension TodoToggleStateUpdateParamas {
    
    enum RecordedState {
        case idle
        case completing
        case reverting
    }
    
    var recordedState: RecordedState {
        switch self {
        case .idle: return .idle
        case .completing: return .completing
        case .reverting: return .reverting
        }
    }
}

class SpyTodoLocalStorage: TodoLocalStorage, @unchecked Sendable {
    
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
    
    var didRemoveAllDoneEvents: Bool?
    func removeAllDoneEvents() async throws {
        self.didRemoveAllDoneEvents = true
    }
    
    var didRemoveTodoWithTagId: String?
    func removeTodosWith(tagId: String) async throws -> [String] {
        self.didRemoveTodoWithTagId = tagId
        return ["some:todo"]
    }
    
    var shouldFailLoadDoneTodo: Bool = false
    func loadDoneTodos(after cursor: TimeInterval?, size: Int) async throws -> [DoneTodoEvent] {
        guard self.shouldFailLoadDoneTodo == false
        else {
            throw RuntimeError("failed")
        }
        return [
            .init(uuid: "cached", name: "cached", originEventId: "some", doneTime: Date())
        ]
    }
    
    func loadDoneTodoEvent(doneEventId: String) async throws -> DoneTodoEvent {
        return .init(uuid: doneEventId, name: "done", originEventId: "origin", doneTime: Date())
    }
    
    var didRemovedDoneTodoIds: [String]?
    func removeDoneTodo(_ doneTodoEventIds: [String]) async throws {
        self.didRemovedDoneTodoIds = doneTodoEventIds
    }
    
    var didRemovedDoneTodoCursor: TimeInterval?
    func removeDoneTodos(pastThan cursor: TimeInterval) async throws {
        self.didRemovedDoneTodoCursor = cursor
    }
    
    var didUpdatedDoneTodos: [DoneTodoEvent]?
    func updateDoneTodos(_ dones: [DoneTodoEvent]) async throws {
        self.didUpdatedDoneTodos = dones
    }
    
    var stubToggleStateMap: [String: TodoTogglingState] = [:]
    func todoToggleState(_ id: String) async throws -> TodoTogglingState {
        if let stub = self.stubToggleStateMap[id] {
            return stub
        }
        let todo = try await self.loadTodoEvent(id)
        return .idle(target: todo)
    }
    
    var didUpdatedTodoToggleStatesMap: [String: [TodoToggleStateUpdateParamas]] = [:]
    func updateTodoToggleState(_ id: String, _ params: TodoToggleStateUpdateParamas) async throws {
        switch params {
        case .idle:
            let todo = try await self.loadTodoEvent(id)
            self.stubToggleStateMap[id] = .idle(target: todo)
        case .completing(let origin):
            self.stubToggleStateMap[id] = .completing(origin: origin, doneId: nil)
        case .reverting:
            self.stubToggleStateMap[id] = .reverting
        }
        self.didUpdatedTodoToggleStatesMap = self.didUpdatedTodoToggleStatesMap |> key(id) %~ { ($0 ?? []) + [params] }
    }
    
    var shouldFailLoadUncompleted: Bool = false
    func loadUncompletedTodos(_ now: Date) async throws -> [TodoEvent] {
        if shouldFailLoadUncompleted {
            throw RuntimeError("failed")
        }
        let todos = (0..<10).map { int in
            return TodoEvent(uuid: "todo:\(int)", name: "cached_todo:\(int)")
        }
        return todos
    }
}
