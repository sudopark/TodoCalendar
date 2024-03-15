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


class TodoRemoteRepositoryImpleTests: BaseTestCase {
    
    private var stubRemote: StubRemoteAPI!
    private var spyTodoCache: SpyTodoLocalStorage!
    
    override func setUpWithError() throws {
        self.stubRemote = .init(responses: self.reponses)
        self.spyTodoCache = .init()
    }
    
    override func tearDownWithError() throws {
        self.stubRemote = nil
        self.spyTodoCache = nil
    }
    
    private func makeRepository() -> TodoRemoteRepositoryImple {
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
            repeatOption: EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
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
        XCTAssertEqual(todo.name, "todo_name")
        XCTAssertEqual(todo.eventTagId, .custom("custom_id"))
        XCTAssertEqual(todo.time, .allDay(0..<100, secondsFromGMT: 300))
        XCTAssertEqual(todo.repeating?.repeatingStartTime, 300)
        XCTAssertEqual(todo.repeating?.repeatOption.compareHash, self.dummyRepeating.repeatOption.compareHash)
        XCTAssertEqual(todo.repeating?.repeatingEndTime, 400)
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

private extension TodoRemoteRepositoryImpleTests {
    
    private var dummySingleTodoResponse: String {
        return """
        {
            "uuid": "new_uuid",
            "name": "todo_name",
            "event_tag_id": "custom_id",
            "event_time": {
                "time_type": "allday",
                "period_start": 0,
                "period_end": 100,
                "seconds_from_gmt": 300
            },
            "repeating": {
                "start": 300,
                "end": 400,
                "option": {

                    "optionType": "every_week",
                    "interval": 1,
                    "dayOfWeek": [],
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
    
    private var reponses: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                method:.post,
                endpoint: TodoAPIEndpoints.make,
                resultJsonString: .success(self.dummySingleTodoResponse)
            ),
            .init(
                method: .patch,
                endpoint: TodoAPIEndpoints.todo("new_uuid"),
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
            )
        ]
    }
}


private class SpyTodoLocalStorage: TodoLocalStorage, @unchecked Sendable {
    
    func loadTodoEvent(_ eventId: String) async throws -> TodoEvent {
        throw RuntimeError("not implemented")
    }
    
    func loadCurrentTodoEvents() async throws -> [TodoEvent] {
        throw RuntimeError("not implemented")
    }
    
    func loadTodoEvents(in range: Range<TimeInterval>) async throws -> [TodoEvent] {
        throw RuntimeError("not implemented")
    }
    
    var didSavedTodoEvent: TodoEvent?
    func saveTodoEvent(_ todo: TodoEvent) async throws {
        self.didSavedTodoEvent = todo
    }
    
    var didUpdatedTodoEvent: TodoEvent?
    func updateTodoEvent(_ todo: TodoEvent) async throws {
        self.didUpdatedTodoEvent = todo
    }
    
    func updateTodoEvents(_ todos: [TodoEvent]) async throws {
        throw RuntimeError("not implemented")
    }
    
    var didSaveDoneTodoEvent: DoneTodoEvent?
    func saveDoneTodoEvent(_ doneEvent: DoneTodoEvent) async throws {
        self.didSaveDoneTodoEvent = doneEvent
    }
    
    var didRemoveTodoId: String?
    func removeTodo(_ eventId: String) async throws {
        self.didRemoveTodoId = eventId
    }
}
