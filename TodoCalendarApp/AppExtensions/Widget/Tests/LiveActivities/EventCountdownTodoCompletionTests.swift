//
//  EventCountdownTodoCompletionTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import TestDoubles

@testable import TodoCalendarAppWidget


struct EventCountdownTodoCompletionTests {

    private func makeCompletion(
        repository: SpyTodoEventRepository, activityEnding: SpyEventCountdownActivityEnding
    ) -> EventCountdownTodoCompletion {
        return EventCountdownTodoCompletion(
            todoRepository: repository, activityEnding: activityEnding
        )
    }

    @Test func completeTodo_whenSucceed_completesWithGivenIdAndEndsActivity() async {
        // given
        let repository = SpyTodoEventRepository()
        let activityEnding = SpyEventCountdownActivityEnding()
        let completion = self.makeCompletion(repository: repository, activityEnding: activityEnding)

        // when
        let didComplete = await completion.completeTodoAndEndActivity("todo-1")

        // then
        #expect(didComplete == true)
        #expect(repository.didCompleteTodoId == "todo-1")
        #expect(activityEnding.didEndCallCount == 1)
    }

    @Test func completeTodo_whenFail_doesNotEndActivity() async {
        // given
        let repository = SpyTodoEventRepository()
        repository.shouldFailComplete = true
        let activityEnding = SpyEventCountdownActivityEnding()
        let completion = self.makeCompletion(repository: repository, activityEnding: activityEnding)

        // when
        let didComplete = await completion.completeTodoAndEndActivity("todo-1")

        // then
        #expect(didComplete == false)
        #expect(activityEnding.didEndCallCount == 0)
    }

    @Test func completeTodo_whenFail_stillRequestsCompletion() async {
        // given
        let repository = SpyTodoEventRepository()
        repository.shouldFailComplete = true
        let activityEnding = SpyEventCountdownActivityEnding()
        let completion = self.makeCompletion(repository: repository, activityEnding: activityEnding)

        // when
        _ = await completion.completeTodoAndEndActivity("todo-1")

        // then
        #expect(repository.didCompleteTodoId == "todo-1")
    }
}


// MARK: - doubles

final class SpyEventCountdownActivityEnding: EventCountdownActivityEnding, @unchecked Sendable {

    private(set) var didEndCallCount: Int = 0

    func endActivities() async {
        self.didEndCallCount += 1
    }
}

final class SpyTodoEventRepository: StubTodoEventRepository, @unchecked Sendable {

    private(set) var didCompleteTodoId: String?

    override func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        self.didCompleteTodoId = eventId
        return try await super.completeTodo(eventId)
    }
}
