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

@testable import Domain


final class TodoEventUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubTodoRepository: StubTodoEventRepository!
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
        |> \.eventTagId .~ "some"
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
        let params = TodoEditParams()
            |> \.eventTagId .~ "some"
        let updated = try? await usecase.updateTodoEvent("id", params)
        
        // then
        XCTAssertNotNil(updated)
    }
    
    // 수정시 필요한 정보 없으면 실패
    func testUsecase_whenUpdateTodoEventWithInvalidParams_fail() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = TodoEditParams()
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
                let params = TodoEditParams()
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
            |> \.time .~ .at(.dummy(0))
            |> \.repeating .~ .init(repeatingStartTime: .dummy(0), repeatOption: EventRepeatingOptions.EveryDay())
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
            in: TimeStamp.dummy(0)..<TimeStamp.dummy(24*3600*10)
        )
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                let params = TodoEditParams()
                    |> \.time .~ .at(.dummy(4))
                    |> \.repeatingUpdateScope .~ .all
                _ = try? await usecase.updateTodoEvent(oldEvent.uuid, params)
            }
        }
        
        // then
        let todoEventTims = todos.map { $0.map { $0.time } }
        XCTAssertEqual(todoEventTims, [
            [.at(.dummy(0))], [.at(.dummy(4))]
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
            in: TimeStamp.dummy(0)..<TimeStamp.dummy(24*3600*10)
        )
        let todos = self.waitOutputs(expect, for: todoSource) {
            Task {
                let params = TodoEditParams()
                    |> \.name .~ oldEvent.name
                    |> \.time .~ .at(.dummy(4))
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
                Pair(uuid: oldEvent.uuid, time: .at(.dummy(0)))
            ],
            [
                Pair(uuid: oldEvent.uuid, time: .at(.dummy(100))),
                Pair(uuid: "new", time: .at(.dummy(4)))
            ]
        ])
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
    
    // todo 이벤트 완료 처리하고 스토어에 저장된 완료된 이벤트 업데이트
    func testUsecase_whenAfterCompleteTodoEvent_updateSharedDoneEvents() {
        // given
        let expect = expectation(description: "todo 이벤트 완료처리하면 저장된 완료된 이벤트 업데이트")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let oldEvent = self.stubTodoEvent()
        
        // when
        let shareKey = ShareDataKeys.doneTodos.rawValue
        let doneSource = self.spyStore.observe([String: DoneTodoEvent].self, key: shareKey)
        let doneEvents = self.waitOutputs(expect, for: doneSource) {
            Task {
                _ = try? await usecase.completeTodo(oldEvent.uuid)
            }
        }
        
        // then
        let doneOriginEventIds = doneEvents.map { $0?.values.map { $0.originEventId } }
        XCTAssertEqual(doneOriginEventIds, [
            nil,
            [oldEvent.uuid]
        ])
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
    func testUsecase_whenRepeatingEvent_notDeleteAfterCOmplete() {
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
}

// MARK: - Load cases + current todo

extension TodoEventUsecaseImpleTests {
    
    private func stubTodoItemsWithTimeAndWithoutTime() {
        let todosWithTime = (0..<10).map { TodoEvent.dummy($0) |> \.time .~ .at(.dummy($0)) }
        let todosWithoutTime = (10..<20).map { TodoEvent.dummy($0) |> \.time .~ nil }
        let todoMap = (todosWithTime + todosWithoutTime).reduce(into: [String: TodoEvent]()) {
            $0[$1.uuid] = $1
        }
        self.spyStore.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, todoMap)
    }
    
    private func stubLoadCurrentTodosFail() {
        self.stubTodoRepository.shouldFailLoadCurrentTodoEvents = true
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
    
    private var todosInRange: Range<TimeStamp> {
        return TimeStamp.dummy(-10)..<TimeStamp.dummy(30)
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
            (-10..<10).map { "id:\($0)" } |> Set.init,
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
}
