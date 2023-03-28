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
    
    // 반복하는 일정은 완료 처리 이후에도 스토어에 저장된 todo 삭제 안함
    func testUsecase_whenRepeatingEvent_notDeleteAfterCOmplete() {
        // given
        let expect = expectation(description: "반복되는 todo는 완료처리 이후에 저장된 공유 할일에서 삭제 안함")
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
        XCTAssertEqual(oldTodoExists, [true])
    }
}
