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
