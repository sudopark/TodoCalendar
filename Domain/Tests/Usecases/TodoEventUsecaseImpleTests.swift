//
//  TodoEventUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/03/26.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

@testable import Domain


final class TodoEventUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubTodoRepository: PrivateTodoRepository!
    private var spyStore: SharedDataStore!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubTodoRepository = .init()
        self.spyStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubTodoRepository = nil
        self.spyStore = nil
    }
    
    private func makeUsecase() -> TodoEventUsecaseImple {
        return TodoEventUsecaseImple(
            todoRepository: self.stubTodoRepository,
            sharedDataStore: self.spyStore
        )
    }
}

// MARK: - test make and edit

extension TodoEventUsecaseImpleTests {
    
    // 생성 이후에 새로 만들어진값 반환
    func testUsecase_makeTodoEvent() async {
        // given
        let usecase = self.makeUsecase()
        // when
        let  params = TodoMakeParams()
        |> \.name .~ "new"
        let newTodo = try? await usecase.makeTodoEvent(params)
        
        // then
        XCTAssertNotNil(newTodo)
    }
    
    // 생성시 필요한 정보 다 입력 안하면 실패
    func testUsecase_whenMakeTodoAndWithoutName_fail() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = TodoMakeParams()
        |> \.eventTagId .~ .custom("some")
        let newTodo = try? await usecase.makeTodoEvent(params)
        
        // then
        XCTAssertNil(newTodo)
    }
    
    // 생성되면 sharedDataStore에 todoEvent 새로 생성된 이벤트 추가됨
    // -> 추후에는 current todo나, 특정기간동안의 todo가 업데이트 되는지 수정 필요
    func testUsecase_whenTodoMade_shared() {
        // given
        let expect = expectation(description: "생성되면 sharedDataStore에 todoEvent 새로 생성된 이벤트 추가됨")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let shareKey = ShareDataKeys.todos.rawValue
        let todoSource = self.spyStore.observe([String: TodoEvent].self, key: shareKey)
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                let params = TodoMakeParams() |> \.name .~ "name"
                return try? await usecase.makeTodoEvent(params)
            }
        }
        
        // then
        let todoNames = todos.map { dict in dict?.mapValues { $0.name } }
        XCTAssertEqual(todoNames, [
            nil,
            ["new": "name"]
        ])
    }
    
    // 수정 이후에 수정된 값 반환
    func testUsecase_updateTodoEvent() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = TodoEditParams(.put)
            |> \.name .~ "name"
            |> \.eventTagId .~ .custom("some")
        let updated = try? await usecase.updateTodoEvent("id", params)
        
        // then
        XCTAssertNotNil(updated)
    }
    
    // 수정시 필요한 정보 없으면 실패
    func testUsecase_whenUpdateTodoEventWithInvalidParams_fail() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = TodoEditParams(.put)
        let updated = try? await usecase.updateTodoEvent("id", params)
        
        // then
        XCTAssertNil(updated)
    }
    
    // 수정 이후에 sharedDataStore에 저장된값 업데이트
    func testUsecase_whenUpdateTodoEvent_updateSharedTodoEvent() {
        // given
        let expect = expectation(description: "todo 이벤트 업데이트시에 공유되는 정보에 업데이트된 값 전달")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let shareKey = ShareDataKeys.todos.rawValue
        self.spyStore.put([String: TodoEvent].self, key: shareKey, [
            "id": TodoEvent(uuid: "id", name: "old")
        ])
        
        // when
        let todoSource = self.spyStore.observe([String: TodoEvent].self, key: shareKey)
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                let params = TodoEditParams(.put)
                    |> \.name .~ "new"
                _ = try? await usecase.updateTodoEvent("id", params)
            }
        }
        
        // then
        let todoNames = todos.map { $0?["id"]?.name }
        XCTAssertEqual(todoNames, ["old", "new"])
    }

    private func stubOldRepeatingTodoEvent() -> TodoEvent {
        let oldEvent = TodoEvent(uuid: "old", name: "some")
            |> \.time .~ .at(0)
            |> \.repeating .~ .init(repeatingStartTime: 0, repeatOption: EventRepeatingOptions.EveryDay())
        let shareKey = ShareDataKeys.todos.rawValue
        self.spyStore.put([String: TodoEvent].self, key: shareKey, [oldEvent.uuid: oldEvent])
        return oldEvent
    }
    
    func testUsecase_whenUpdateRepeatingAllTodos_updateAll() {
        // given
        let expect = self.expectation(description: "반복일정 전체를 업데이트하면 다 바뀜")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let oldEvent = self.stubOldRepeatingTodoEvent()
        
        // when
        let todoSource = usecase.todoEvents(
            in: 0..<24*3600*10
        )
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                let params = TodoEditParams(.put)
                    |> \.name .~ "name"
                    |> \.time .~ .at(4)
                    |> \.repeatingUpdateScope .~ .all
                _ = try? await usecase.updateTodoEvent(oldEvent.uuid, params)
            }
        }
        
        // then
        let todoEventTims = todos.map { $0.map { $0.time } }
        XCTAssertEqual(todoEventTims, [
            [.at(0)], [.at(4)]
        ])
    }
    
    func testUsecase_whenUpdateRepeatingTodoOnlyThisTime_makeNewOneWithUpdatedAndSkipToNextOldEvent() {
        // given
        let expect = expectation(description: "반복되는 todo 이번만 바꾼경우, 업데이트 옵션으로 새로운 todo 만들고 기존 todo는 다음으로 넘어감")
        expect.expectedFulfillmentCount = 2
        expect.assertForOverFulfill = false
        let usecase = self.makeUsecase()
        let oldEvent = self.stubOldRepeatingTodoEvent()
        
        // when
        let todoSource = usecase.todoEvents(
            in: 0..<24*3600*10
        )
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                let params = TodoEditParams(.put)
                    |> \.name .~ oldEvent.name
                    |> \.time .~ .at(4)
                    |> \.repeatingUpdateScope .~ .onlyThisTime
                _ = try? await usecase.updateTodoEvent(oldEvent.uuid, params)
            }
        }
        
        // then
        struct Pair: Equatable { let uuid: String; let time: EventTime? }
        let todoIdAndTimePair = todos.map {
            $0.map { Pair(uuid: $0.uuid, time: $0.time) }
                .sorted(by: { $0.uuid > $1.uuid })
        }
        XCTAssertEqual(todoIdAndTimePair, [
            [
                Pair(uuid: oldEvent.uuid, time: .at(0))
            ],
            [
                Pair(uuid: oldEvent.uuid, time: .at(100)),
                Pair(uuid: "new", time: .at(4))
            ]
        ])
    }
    
    // remove todo
    func testUsecase_removeTodo() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when + then
        try await usecase.removeTodo("some", onlyThisTime: false)
    }
    
    private func makeUsecaseWithStubWillRemovingTodo(
        nextEventExists: Bool
    ) -> TodoEventUsecaseImple {
        self.stubTodoRepository.stubRemoveTodoNextRepeatingExists = nextEventExists
        let todo = TodoEvent(uuid: "will_removing_todo", name: "old")
        self.spyStore.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, [todo.uuid: todo]
        )
        let usecase = self.makeUsecase()
        return usecase
    }
    
    private var willRemovingTodoAtStore: AnyPublisher<TodoEvent?, Never> {
        return self.spyStore
            .observe([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue)
            .map { $0?["will_removing_todo"] }
            .eraseToAnyPublisher()
    }
    
    // remove todo -> update shared data as nil
    func testUsecase_whenRemoveTodo_removeFromShared() {
        // given
        let expect = expectation(description: "todo 삭제 이후 공유 스토어에서 삭제")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStubWillRemovingTodo(nextEventExists: false)
        
        // when
        let todos = self.waitOutputs(expect, for: self.willRemovingTodoAtStore) {
            Task {
                try? await usecase.removeTodo("will_removing_todo", onlyThisTime: false)
            }
        }
        
        // then
        let todoIsNils = todos.map { $0 == nil }
        XCTAssertEqual(todoIsNils, [false, true])
    }
    
    // remove repeating todo only this time + next repeating event exists -> update shared data as next event
    func testUsecase_whenRemoveTodoAndNextRepeatingTodoExists_provideSharedTodoAsNextEvent() {
        // given
        let expect = expectation(description: "반복이벤트 중 이번만 삭제하는 경우 다음이벤트로 대체")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStubWillRemovingTodo(nextEventExists: true)
        
        // when
        let todos = self.waitOutputs(expect, for: self.willRemovingTodoAtStore) {
            Task {
                try? await usecase.removeTodo("will_removing_todo", onlyThisTime: true)
            }
        }
        
        // then
        let todoNames = todos.map { $0?.name }
        XCTAssertEqual(todoNames, ["old", "next"])
    }
    
    // remove repeating todo only this time + next repeating event not exists -> update shared data as nil
    func testUsecase_whenRemoveTodoAndNextRepeatingTodoNotExists_provideSharedTodoAsNextEvent() {
        // given
        let expect = expectation(description: "반복이벤트 중 이번만 삭제하는 경우 다음이벤트로 대체해야하지만 없으면 nil")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStubWillRemovingTodo(nextEventExists: false)
        
        // when
        let todos = self.waitOutputs(expect, for: self.willRemovingTodoAtStore) {
            Task {
                try? await usecase.removeTodo("will_removing_todo", onlyThisTime: true)
            }
        }
        
        // then
        let todoIsNils = todos.map { $0 == nil }
        XCTAssertEqual(todoIsNils, [false, true])
    }
}


// MARK: - TodoEventUsecase

extension TodoEventUsecaseImpleTests {
    
    @discardableResult
    private func stubTodoEvent(isRepeating: Bool = false) -> TodoEvent {
        let event = TodoEvent.dummy()
        let shareKey = ShareDataKeys.todos.rawValue
        self.spyStore.put([String: TodoEvent].self, key: shareKey, [event.uuid: event])
        
        self.stubTodoRepository.doneEventIsRepeating = isRepeating
        return event
    }
    
    // todo 이벤트 완료 처리
    func testUsecase_completeTodoEvent() async {
        // given
        let usecase = self.makeUsecase()
        let oldEvent = self.stubTodoEvent()
        
        // when
        let doneEvent = try? await usecase.completeTodo(oldEvent.uuid)
        
        // then
        XCTAssertNotNil(doneEvent)
    }
    
    // 반복 안하는 일정은 완료 처리 이후에 스토어에 저장된 todo 삭제
    func testUsecase_whenNotRepeatingEvent_deleteSharedTodoAfterComplete() {
        // given
        let expect = expectation(description: "반복안하는 todo는 완료처리 이후에 저장된 공유 할일에서 제거")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let oldEvent = self.stubTodoEvent(isRepeating: false)
        
        // when
        let shareKey = ShareDataKeys.todos.rawValue
        let todoSource = self.spyStore.observe([String: TodoEvent].self, key: shareKey)
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                _ = try await usecase.completeTodo(oldEvent.uuid)
            }
        }
        
        // then
        let oldEventExists = todos.map { $0?.keys.contains(oldEvent.uuid) }
        XCTAssertEqual(oldEventExists, [true, false])
    }
    
    // 반복하는 일정은 완료 처리 이후에도 스토어에 저장된 이전 todo 삭제하고 새로운 todo로 업데이트
    func testUsecase_whenRepeatingEvent_notDeleteAfterComplete() {
        // given
        let expect = expectation(description: "반복되는 todo는 완료처리 이후에 저장된 공유 할일에서 삭제 안함")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecase()
        let oldEvent = self.stubTodoEvent(isRepeating: true)
        
        // when
        let shareKey = ShareDataKeys.todos.rawValue
        let todoSource = self.spyStore.observe([String: TodoEvent].self, key: shareKey)
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                _ = try? await usecase.completeTodo(oldEvent.uuid)
            }
        }
        
        // then
        let oldTodoExists = todos.map { $0?.keys.contains(oldEvent.uuid) }
        let newTodoExists = todos.map { $0?.keys.contains("next")}
        XCTAssertEqual(oldTodoExists, [true, false, false])
        XCTAssertEqual(newTodoExists, [false, false, true])
    }
    
    func testUsecase_revertDoneTodo() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let reverted = try await usecase.revertCompleteTodo("done")
        
        // then
        XCTAssertEqual(reverted.uuid, "reverted")
    }
    
    func testUsecase_whenAfterRevertTodo_updateSharedDataStore() {
        // given
        let expect = expectation(description: "완료 todo revert 이후에 공유 스토어에 todo 업데이트")
        let usecase = self.makeUsecase()
        
        // when
        let shareKey = ShareDataKeys.todos.rawValue
        let source = self.spyStore.observe([String: TodoEvent].self, key: shareKey)
        let todos = self.waitOutputs(expect, for: source) {
            Task {
                _ = try await usecase.revertCompleteTodo("done")
            }
        }
        
        // then
        let ids = todos.map { ts in ts?.map { $0.key }}
        XCTAssertEqual(ids, [
            nil, ["reverted"]
        ])
    }
}

// MARK: - Load cases + current todo

extension TodoEventUsecaseImpleTests {
    
    private func stubTodoItemsWithTimeAndWithoutTime() {
        let todosWithTime = (0..<10).map { TodoEvent.dummy($0) |> \.time .~ .at(TimeInterval($0)) }
        let todosWithoutTime = (10..<20).map { TodoEvent.dummy($0) |> \.time .~ nil }
        let todoMap = (todosWithTime + todosWithoutTime).reduce(into: [String: TodoEvent]()) {
            $0[$1.uuid] = $1
        }
        self.spyStore.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, todoMap)
    }
    
    private func stubLoadCurrentTodosFail() {
        self.stubTodoRepository.shouldFailLoadCurrentTodoEvents = true
    }
    
    private func stubLoadCurrrentTodoWithOnly10to14() {
        self.stubTodoRepository.stubCurrrentTodo = (10..<15).map { TodoEvent.dummy($0) |> \.time .~ nil }
    }
    
    private func stubLoadTodosInRangeOnly0to8() {
        self.stubTodoRepository.stubTodosInRange = (0..<8).map {
            TodoEvent.dummy($0) |> \.time .~ .at(TimeInterval($0))
        }
    }

    func testUsecase_whenCachedCurrentTodoIsNotEmpty_refreshCurrentTodos() {
        // given
        let expect = expectation(description: "캐시된거 있을때 currenct todo 스트림 반환")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        
        // when()
        let currentTodos = self.waitOutputs(expect, for: usecase.currentTodoEvents) {
            usecase.refreshCurentTodoEvents()
        }
        
        // then
        let idsSets = currentTodos.map { todos in
            Set(todos.map { $0.uuid })
        }
        XCTAssertEqual(idsSets, [
            (10..<20).map { "id:\($0)" } |> Set.init,
            (10..<30).map { "id:\($0)" } |> Set.init
        ])
    }
    
    func testUsecase_whenCachedCurrentTodoIsEmpty_refreshCurrentTodos() {
        // given
        let expect = expectation(description: "캐시된거 없을때 currenct todo 스트림 반환")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let currentTodos = self.waitOutputs(expect, for: usecase.currentTodoEvents) {
            usecase.refreshCurentTodoEvents()
        }
        
        // then
        let idsSets = currentTodos.map { todos in
            todos.map { $0.uuid } |> Set.init
        }
        XCTAssertEqual(idsSets, [
            [],
            (10..<30).map { "id:\($0)" } |> Set.init
        ])
    }
    
    func testUsecase_whenRefreshCurrentTodoFails_justReturnCached() {
        // given
        let expect = expectation(description: "refresh 실패하면 캐시된거만 반환")
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        self.stubLoadCurrentTodosFail()
        
        // when
        let currentTodos = self.waitOutputs(expect, for: usecase.currentTodoEvents) {
            usecase.refreshCurentTodoEvents()
        }
        
        // then
        let idsSets = currentTodos.map { todos in
            todos.map { $0.uuid } |> Set.init
        }
        XCTAssertEqual(idsSets, [
            (10..<20).map { "id:\($0)" } |> Set.init
        ])
    }
    
    func testUsecase_whenMakeNewTodoEventWithoutTime_updateCurrentTodo() {
        // given
        let expect = expectation(description: "새로만들어진 currenct todo 이벤트도 반환")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        
        // when
        let currentTodos = self.waitOutputs(expect, for: usecase.currentTodoEvents) {
            let params = TodoMakeParams() |> \.name .~ "new"
            Task {
                _ = try? await usecase.makeTodoEvent(params)
            }
        }
        
        // then
        let idsSets = currentTodos.map { todos in
            todos.map { $0.uuid } |> Set.init
        }
        XCTAssertEqual(idsSets, [
            (10..<20).map { "id:\($0)" } |> Set.init,
            ((10..<20).map { "id:\($0)" } + ["new"]) |> Set.init
        ])
    }
    
    func testUsecase_whenRefershCurrentTodo_excludeRemoved() {
        // given
        let expect = expectation(description: "current todo refresh시에 삭제된것은 캐시에서 제외")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        self.stubLoadCurrrentTodoWithOnly10to14()
        
        // when
        let currentTodos = self.waitOutputs(expect, for: usecase.currentTodoEvents) {
            usecase.refreshCurentTodoEvents()
        }
        // then
        let ids = currentTodos.map { ts in ts.map { $0.uuid }.sorted() }
        XCTAssertEqual(ids, [
            Array(10..<20).map { "id:\($0)" },
            Array(10..<15).map { "id:\($0)"}
        ])
    }
    
    func testUsecase_whenCompleteTodoEvent_removeFromCurrentTodo() {
        // given
        let expect = expectation(description: "완료된 currenct todo 이벤트는 제외하고 반환")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        
        // when
        let currentTodos = self.waitOutputs(expect, for: usecase.currentTodoEvents) {
            Task {
                _ = try? await usecase.completeTodo("id:12")
            }
        }
        
        // then
        let hasTodo12 = currentTodos.map { todos in
            todos.first(where: { $0.uuid == "id:12" }) != nil
        }
        XCTAssertEqual(hasTodo12, [true, false])
    }
}


// MARK: - load case + in range

extension TodoEventUsecaseImpleTests {
    
    private var todosInRange: Range<TimeInterval> {
        return -10..<30
    }
    
    private func stubLoadTodosInPeriodFail() {
        self.stubTodoRepository.shouldFailLoadTodosInRange = true
    }
    
    func testUsecase_loadTodoEventsInPeriodWithCachedAndRefresh() {
        // given
        let expect = expectation(description: "특정 기간동안의 todo 로드 + 메모리에 캐싱된거 있는 경우")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        
        // when
        let todos = self.waitOutputs(expect, for: usecase.todoEvents(in: self.todosInRange)) {
            usecase.refreshTodoEvents(in: self.todosInRange)
        }
        
        // then
        let idsSets = todos.map { todos in
            todos.map { $0.uuid } |> Set.init
        }
        XCTAssertEqual(idsSets, [
            (0..<10).map { "id:\($0)" } |> Set.init,
            (-10..<0).map { "id:\($0)" } |> Set.init,
        ])
    }
    
    func testUsecase_loadTodoEventsInPeriodWithoutCachedAndRefresh() {
        // given
        let expect = expectation(description: "특정 기간동안의 todo 로드 + 메모리에 케싱된거 없는 경우")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let todos = self.waitOutputs(expect, for: usecase.todoEvents(in: self.todosInRange)) {
            usecase.refreshTodoEvents(in: self.todosInRange)
        }
        
        // then
        let idsSets = todos.map { todos in
            todos.map { $0.uuid } |> Set.init
        }
        XCTAssertEqual(idsSets, [
            [],
            (-10..<0).map { "id:\($0)" } |> Set.init,
        ])
    }
    
    func testUsecase_whenLoadFailTodoEventsInPeriod_justReturnCached() {
        // given
        let expect = self.expectation(description: "특정 기간동안의 todo 로드 + 새로 로드 실패 -> 메모리에 캐싱된것만 반환")
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        self.stubLoadTodosInPeriodFail()
        
        // when
        let todos = self.waitOutputs(expect, for: usecase.todoEvents(in: self.todosInRange)) {
            usecase.refreshTodoEvents(in: self.todosInRange)
        }
        
        // then
        let idsSets = todos.map { todos in
            todos.map { $0.uuid } |> Set.init
        }
        XCTAssertEqual(idsSets, [
            (0..<10).map { "id:\($0)" } |> Set.init,
        ])
    }
    
    func testUsecase_whenLoadTodoEventsInPeriod_exlcudeRemoved() {
        // given
        let expect = expectation(description: "특정 기간동안의 todo로드시에 삭제된것은 캐시에서 제외하고 로드")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        self.stubTodoItemsWithTimeAndWithoutTime()
        self.stubLoadTodosInRangeOnly0to8()
        
        // when
        let todos = self.waitOutputs(expect, for: usecase.todoEvents(in: self.todosInRange)) {
            usecase.refreshTodoEvents(in: self.todosInRange)
        }
        
        // then
        let ids = todos.map { ts in ts.map { $0.uuid }.sorted() }
        XCTAssertEqual(ids, [
            Array(0..<10).map { "id:\($0)" },
            Array(0..<8).map { "id:\($0)" }
        ])
    }
}


// MARK: - load todo in period + include allday

extension TodoEventUsecaseImpleTests {
    
    // kst에서 allday로 2023년 7월 23일 ~ 25일까지 지정했음 (GMT + 9)
    // pdt 7월 23~25 조회시에 걸려야함
    // t+14 23~25 조회시에도 걸려야함
    // t-12 23~25 조회시에도 걸려야함
    
    private func dummyAllDayLoadRange(timeZone: TimeZone) -> Range<TimeInterval> {
        return try! TimeInterval.range(
            from: "2023-07-23 00:00:00",
            to: "2023-07-25 23:59:59",
            in: timeZone
        )
    }
    
    private func makeUsecaseWithAllDayTodoStubbing() -> TodoEventUsecaseImple {
        
        let usecase = self.makeUsecase()
        let kstTimeZone = TimeZone(abbreviation: "KST")!
        let range = self.dummyAllDayLoadRange(timeZone: kstTimeZone)
        let todo = TodoEvent(uuid: "allday", name: "allday-todo-event")
            |> \.time .~ .allDay(range, secondsFromGMT: TimeInterval(kstTimeZone.secondsFromGMT()))
        self.spyStore.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, [todo.uuid: todo])
        return usecase
    }
    
    func testUsecase_provoideTodoEventWithAlldayEventTime_otherTimeZones() {
        // given
        func parameterizeTests(_ timeZone: TimeZone) {
            // given
            let expect = expectation(description: "kst timezone에서 저장된 allday 2023.07.23~07.25 이벤트를 다른 timezone 에서도 조회할 수 있어야함")
            expect.assertForOverFulfill = false
            let usecase = self.makeUsecaseWithAllDayTodoStubbing()
            
            // when
            let range = self.dummyAllDayLoadRange(timeZone: timeZone)
            let events = self.waitFirstOutput(expect, for: usecase.todoEvents(in: range))
            
            // then
            XCTAssertEqual(events?.count, 1)
            let allDayEvent = events?.first(where: { $0.uuid == "allday" })
            let kstTimeZone = TimeZone(abbreviation: "KST")!
            let kstRange = self.dummyAllDayLoadRange(timeZone: kstTimeZone)
            XCTAssertEqual(
                allDayEvent?.time,
                .allDay(kstRange, secondsFromGMT: TimeInterval(kstTimeZone.secondsFromGMT()))
            )
        }
        
        // when
        let timeZones: [TimeZone] = [
            .init(abbreviation: "UTC")!, .init(abbreviation: "KST")!, .init(abbreviation: "PDT")!,
            .init(secondsFromGMT: 14 * 3600)!, .init(secondsFromGMT: -12 * 3600)!
        ]
        
        // then
        timeZones.forEach {
            parameterizeTests($0)
        }
    }
}

extension TodoEventUsecaseImpleTests {
    
    private func makeUsecaseWithStubUncompleted() -> TodoEventUsecaseImple {
        let todos1 = (0..<10).map { TodoEvent(uuid: "id:\($0)", name: "name:\($0)") }
        let todos2 = (10..<20).map { TodoEvent(uuid: "id:\($0)", name: "name:\($0)") }
        self.stubTodoRepository.stubUncompletedTodos = [todos1, todos2]
        return self.makeUsecase()
    }
    
    func testUsecase_refreshUncompletedTodos() {
        // given
        let expect = expectation(description: "완료되지않은 할일 조회")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecaseWithStubUncompleted()
        
        // when
        let todoLists = self.waitOutputs(expect, for: usecase.uncompletedTodos) {
            usecase.refreshUncompletedTodos()
            usecase.refreshUncompletedTodos()
        }
        
        // then
        let idLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(idLists, [
            [],
            (0..<10).map { "id:\($0)" },
            (10..<20).map { "id:\($0)" }
        ])
    }
    
    func testUsecae_whenAfterUpdateUncompletedTodo_updateList() {
        // given
        let expect = expectation(description: "완료되지않은 할일을 업데이트 한 경우, 업데이트해서 결과 전파")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecaseWithStubUncompleted()
        
        // when
        let todoLists = self.waitOutputs(expect, for: usecase.uncompletedTodos, timeout: 0.1) {
            usecase.refreshUncompletedTodos()
            
            Task {
                _ = try await usecase.updateTodoEvent("id:4", .init(.put) |> \.name .~ "new name")
            }
        }
        
        // then
        let nameLists = todoLists.map { ts in ts.map { $0.name } }
        XCTAssertEqual(nameLists, [
            [],
            (0..<10).map { "name:\($0)" },
            (0..<4).map { "name:\($0)" } + ["new name"] + (5..<10).map { "name:\($0)" }
        ])
    }
    
    func testUsecase_whenAfterCompleteUncompletedTodo_removeFromUncompletedTodoList() {
        // given
        let expect = expectation(description: "완료되지않은 할일을 완료처리 한 경우, 완료되지않은 할일 목록에서 제거해서 결과 전파")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecaseWithStubUncompleted()
        
        // when
        let todoLists = self.waitOutputs(expect, for: usecase.uncompletedTodos, timeout: 0.1) {
            usecase.refreshUncompletedTodos()
            
            Task {
                _ = try await usecase.completeTodo("id:4")
            }
        }
        
        // then
        let nameLists = todoLists.map { ts in ts.map { $0.name } }
        XCTAssertEqual(nameLists, [
            [],
            (0..<10).map { "name:\($0)" },
            (0..<4).map { "name:\($0)" } + (5..<10).map { "name:\($0)" }
        ])
    }
    
    func testUsecase_whenAfterRemoveUncompletedTodo_removeFromUncompletedTodoList() {
        // given
        let expect = expectation(description: "완료되지않은 할일을 제거한 경우, 완료되지않은 할일 목록에서 제거해서 결과 전파")
        expect.expectedFulfillmentCount = 4
        let usecase = self.makeUsecaseWithStubUncompleted()
        
        // when
        let todoLists = self.waitOutputs(expect, for: usecase.uncompletedTodos, timeout: 0.1) {
            usecase.refreshUncompletedTodos()
            
            Task {
                try await usecase.removeTodo("id:4", onlyThisTime: false)
                try await usecase.removeTodo("id:5", onlyThisTime: true)
            }
        }
        
        // then
        let nameLists = todoLists.map { ts in ts.map { $0.name } }
        XCTAssertEqual(nameLists, [
            [],
            (0..<10).map { "name:\($0)" },
            (0..<4).map { "name:\($0)" } + (5..<10).map { "name:\($0)" },
            (0..<4).map { "name:\($0)" } + (6..<10).map { "name:\($0)" }
        ])
    }
}

// MARK: - skip todo

extension TodoEventUsecaseImpleTests {
    
    private func makeUsecaseWithStubRepeatingTodo(
        nextTodoTime: EventTime? = nil
    ) -> TodoEventUsecaseImple {
        let todo = TodoEvent(uuid: "repeating", name: "todo")
            |> \.time .~ .at(10)
            |> \.repeating .~ EventRepeating(
                repeatingStartTime: 10, repeatOption: EventRepeatingOptions.EveryDay()
            )
        self.stubTodoRepository.stubTodosInRange = [todo]
        self.stubTodoRepository.stubUncompletedTodos = [[todo]]
        self.stubTodoRepository.stubSkipTodoTime = nextTodoTime
        return self.makeUsecase()
    }
    
    // skip to next
    func testUsecaes_skipTodoToNext() async throws {
        // given
        let usecase = self.makeUsecaseWithStubRepeatingTodo()
        
        // when
        let skipped = try await usecase.skipRepeatingTodo("repeating", .next)
        
        // then
        XCTAssertEqual(skipped.uuid, "repeating")
        XCTAssertEqual(skipped.time, .at(20))
    }
    
    // skip to some time
    func testUsecase_skipToSomeTime() async throws {
        // given
        let usecase = self.makeUsecaseWithStubRepeatingTodo()
        
        // when
        let skipped = try await usecase.skipRepeatingTodo(
            "repeating", .until(.at(100))
        )
        
        // then
        XCTAssertEqual(skipped.uuid, "repeating")
        XCTAssertEqual(skipped.time, .at(100))
    }
    
    // when skip todo update event list
    func testUsecase_whenSkipTodo_updateTodoList() {
        // given
        let expect = expectation(description: "todo skip시에 조회중인 todo list 업데이트")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecaseWithStubRepeatingTodo()
        
        // when
        let source = usecase.todoEvents(in: 0..<200)
        let todoLists = self.waitOutputs(expect, for: source, timeout: 0.01) {
            
            Task {
                usecase.refreshTodoEvents(in: 0..<200)
                
                _ = try await usecase.skipRepeatingTodo("repeating", .next)
            }
        }
        
        // then
        let repeatingTodos = todoLists.map { ts in ts.first(where: { $0.uuid == "repeating" })}
        XCTAssertEqual(repeatingTodos.map { $0?.time }, [
            nil, .at(10), .at(20)
        ])
    }
    
    // when skip todo update uncompleted todo
    func testUsecase_whenSkipTodo_updateUncompletedTodo() {
        // given
        let expect = expectation(description: "todo skip시에 조회중인 미완료 todo list 업데이트")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecaseWithStubRepeatingTodo()
        
        // when
        let todoLists = self.waitOutputs(expect, for: usecase.uncompletedTodos) {
            Task {
                usecase.refreshUncompletedTodos()
                
                _ = try await usecase.skipRepeatingTodo("repeating", .next)
            }
        }
        
        // then
        let repeatingTodos = todoLists.map { ts in ts.first(where: { $0.uuid == "repeating" })}
        XCTAssertEqual(repeatingTodos.map { $0?.time }, [
            nil, .at(10), .at(20)
        ])
    }
    
    func testUsecase_whenSkipTodoAndSkippedTodoEventTimeIsFuture_removeFromUncompletedTodo() {
        // given
        let expect = expectation(description: "todo skip시에 업데이트된 todo가 미래의 todo라면 완료 목록에서 제거")
        expect.expectedFulfillmentCount = 4
        let usecase = self.makeUsecaseWithStubRepeatingTodo(
            nextTodoTime: .at(Date().timeIntervalSince1970 + 1000)
        )
        
        // when
        let todoLists = self.waitOutputs(expect, for: usecase.uncompletedTodos, timeout: 0.01) {
            Task {
                usecase.refreshUncompletedTodos()
                
                _ = try await usecase.skipRepeatingTodo("repeating", .next)
            }
        }
        
        // then
        let repeatingTodos = todoLists.map { ts in ts.first(where: { $0.uuid == "repeating" })}
        XCTAssertEqual(repeatingTodos.map { $0 != nil }, [
            false, true, true, false
        ])
    }
}

private final class PrivateTodoRepository: StubTodoEventRepository, @unchecked Sendable {
    
    var stubCurrrentTodo: [TodoEvent]?
    override func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], any Error> {
        if let stub = self.stubCurrrentTodo {
            return Just(stub).mapNever().eraseToAnyPublisher()
        }
        return super.loadCurrentTodoEvents()
    }
    
    var stubTodosInRange: [TodoEvent]?
    override func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error> {
        if let stub = self.stubTodosInRange {
            return Just(stub).mapNever().eraseToAnyPublisher()
        }
        return super.loadTodoEvents(in: range)
    }
    
    var stubUncompletedTodos: [[TodoEvent]] = []
    override func loadUncompletedTodos() -> AnyPublisher<[TodoEvent], any Error> {
        guard !stubUncompletedTodos.isEmpty
        else {
            return Just([]).mapNever().eraseToAnyPublisher()
        }
        let first = self.stubUncompletedTodos.removeFirst()
        return Just(first).mapNever().eraseToAnyPublisher()
    }
    
    var stubSkipTodoTime: EventTime?
    override func skipRepeatingTodo(_ todoId: String) async throws -> TodoEvent {
        let todo = TodoEvent(uuid: "repeating", name: "todo")
            |> \.time .~ (self.stubSkipTodoTime ?? .at(20))
            |> \.repeating .~ EventRepeating(
                repeatingStartTime: 10, repeatOption: EventRepeatingOptions.EveryDay()
            )
        return todo
    }
}
