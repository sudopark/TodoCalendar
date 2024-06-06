//
//  TodoToggleUsecaseImpleTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 6/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles


class TodoToggleUsecaseImpleTests: BaseTestCase {
    
    private func makeUsecase(
        isAlreadyTogglingId: String? = nil
    ) -> TodoToggleUsecaseImple {
        
        let repository = PrivateStubRepository()
        
        let store = FakeStorage()
        if let id = isAlreadyTogglingId {
            store.updateIsToggling(id: id, true)
        }
        
        return .init(
            processStorage: store, todoRepository: repository
        )
    }
}

extension TodoToggleUsecaseImpleTests {
    
    func testUsecase_toggle_complete() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let result = try await usecase.toggleTodo("not_done_todo", nil)
        
        // then
        XCTAssertEqual(result?.compareKey, "completed")
    }
    
    func testUsecase_toggle_revert() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let result = try await usecase.toggleTodo("already_done_todo", nil)
        
        // then
        XCTAssertEqual(result?.compareKey, "reverted")
    }
    
    func testUsecase_whenAlreadyToggling_ignore() async throws {
        // given
        let usecase = self.makeUsecase(isAlreadyTogglingId: "on_going")
        
        // when
        let resultIgnore = try await usecase.toggleTodo("on_going", nil)
        let resultDone = try await usecase.toggleTodo("not_done_todo", nil)
        
        // then
        XCTAssertNil(resultIgnore)
        XCTAssertEqual(resultDone?.compareKey, "completed")
    }
}


private final class FakeStorage: TodoTogglingProcessStorage {
    
    private var flagMap: [String: Bool] = [:]
    
    func isToggling(id: String) -> Bool {
        return self.flagMap[id] ?? false
    }
    
    func updateIsToggling(id: String, _ newValue: Bool) {
        self.flagMap[id] = newValue
    }
}


private final class PrivateStubRepository: StubTodoEventRepository {
    
    override func toggleTodo(_ todoId: String, _ eventTime: EventTime?) async throws -> TodoToggleResult {
        
        if todoId == "not_done_todo" {
            let done = DoneTodoEvent(uuid: "done", name: "done", originEventId: todoId, doneTime: .init())
            return .completed(done)
        } else {
            let todo = TodoEvent(uuid: todoId, name: "some")
            return .reverted(todo)
        }
    }
}


extension TodoToggleResult {
    
    fileprivate var compareKey: String {
        switch self {
        case .completed: return "completed"
        case .reverted: return "reverted"
        }
    }
}
