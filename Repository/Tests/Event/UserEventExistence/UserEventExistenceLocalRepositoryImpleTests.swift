//
//  UserEventExistenceLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import SQLiteService
import Domain
import UnitTestHelpKit

@testable import Repository


@Suite("UserEventExistenceLocalRepositoryImpleTests", .serialized)
final class UserEventExistenceLocalRepositoryImpleTests: LocalTestable {

    let sqliteService: SQLiteService = .init()

    private var todoLocalStorage: TodoLocalStorageImple {
        return TodoLocalStorageImple(sqliteService: self.sqliteService)
    }

    private var scheduleLocalStorage: ScheduleEventLocalStorageImple {
        return ScheduleEventLocalStorageImple(sqliteService: self.sqliteService)
    }

    private func makeRepository() -> UserEventExistenceLocalRepositoryImple {
        return UserEventExistenceLocalRepositoryImple(
            todoLocalStorage: self.todoLocalStorage,
            scheduleLocalStorage: self.scheduleLocalStorage
        )
    }
}


extension UserEventExistenceLocalRepositoryImpleTests {

    @Test("저장된 이벤트가 없으면 없다고 답한다")
    func repository_whenNoEventSaved_hasNoEvent() async throws {
        try await self.runTestWithOpenClose("user_event_existence_empty") {
            // given
            let repository = self.makeRepository()

            // when
            let hasAnyEvent = try await repository.fetchHasAnyEvent()

            // then
            #expect(hasAnyEvent == false)
        }
    }

    @Test("todo 가 저장돼 있으면 있다고 답한다")
    func repository_whenTodoSaved_hasAnyEvent() async throws {
        try await self.runTestWithOpenClose("user_event_existence_todo") {
            // given
            let repository = self.makeRepository()
            try await self.todoLocalStorage.saveTodoEvent(
                TodoEvent(uuid: "todo", name: "some")
            )

            // when
            let hasAnyEvent = try await repository.fetchHasAnyEvent()

            // then
            #expect(hasAnyEvent == true)
        }
    }

    @Test("todo 는 없고 일정만 저장돼 있어도 있다고 답한다")
    func repository_whenOnlyScheduleSaved_hasAnyEvent() async throws {
        try await self.runTestWithOpenClose("user_event_existence_schedule") {
            // given
            let repository = self.makeRepository()
            try await self.scheduleLocalStorage.saveScheduleEvent(
                ScheduleEvent(uuid: "schedule", name: "some", time: .at(100))
            )

            // when
            let hasAnyEvent = try await repository.fetchHasAnyEvent()

            // then
            #expect(hasAnyEvent == true)
        }
    }
}
