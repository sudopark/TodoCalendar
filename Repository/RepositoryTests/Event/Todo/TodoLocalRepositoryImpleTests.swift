//
//  TodoLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/05/21.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import AsyncFlatMap
import UnitTestHelpKit

@testable import Repository


class TodoLocalRepositoryImpleTests: BaseLocalTests, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    var localStorage: TodoLocalStorage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.cancelBag = .init()
        self.localStorage = .init(sqliteService: self.sqliteService)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.cancelBag = nil
        self.localStorage = nil
    }
    
    private func makeRepository() -> TodoLocalRepositoryImple {
        return TodoLocalRepositoryImple(localStorage: self.localStorage)
    }
}


extension TodoLocalRepositoryImpleTests {
    
    private func dummyRange(_ range: Range<Int>) -> Range<TimeInterval> {
        let oneDay: TimeInterval = 24 * 3600
        return TimeInterval(range.lowerBound)*oneDay
        ..<
        TimeInterval(range.upperBound)*oneDay
    }
    
    private var dummyMakeParams: TodoMakeParams {
        let option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
            |> \.interval .~ 2
        let repeating = EventRepeating(repeatingStartTime: TimeStamp(100, timeZone: "KST"), repeatOption: option)
            |> \.repeatingEndTime .~ TimeStamp(200, timeZone: "KST")
        return TodoMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ "some"
            |> \.time .~ .period(
                TimeStamp(0, timeZone: "KST")..<TimeStamp(100, timeZone: "KST")
            )
            |> \.repeating .~ repeating
    }
    
    // make
    func testRepository_makeNewTodo() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let todo = try? await repository.makeTodoEvent(params)
        
        // then
        XCTAssertNotNil(todo)
    }
    
    private func stubSaveTodo(
        _ todos: [TodoEvent]
    ) {
        let expect = expectation(description: "wait-save")
        
        let saving: AsyncFlatMapPublisher<Void, Error, Void> = Publishers.create {
            return try await self.localStorage.updateTodoEvents(todos)
        }
        let _ = self.waitFirstOutput(expect, for: saving, timeout: 1)
    }
    
    // make and load/
    func testRepository_makeNewTodoAndLoad() {
        // given
        let dummy = TodoEvent(self.dummyMakeParams)!
        self.stubSaveTodo([dummy])
        
        let expect = expectation(description: "저장 이후에 로드")
        let repository = self.makeRepository()
        
        // when
        let load = repository.loadTodoEvents(in: self.dummyRange(0..<10))
        let events = self.waitFirstOutput(expect, for: load, timeout: 1)
        
        // then
        XCTAssertEqual(events?.count, 1)
        let event = events?.first
        XCTAssertEqual(event?.name, "new")
        XCTAssertEqual(event?.eventTagId, "some")
        XCTAssertEqual(event?.time, .period(TimeStamp(0, timeZone: "KST")..<TimeStamp(100, timeZone: "KST")))
        let repeatOption = event?.repeating?.repeatOption as? EventRepeatingOptions.EveryWeek
        XCTAssertEqual(repeatOption?.interval, 2)
        XCTAssertEqual(event?.repeating?.repeatingStartTime, .init(100, timeZone: "KST"))
        XCTAssertEqual(event?.repeating?.repeatingEndTime, .init(200, timeZone: "KST"))
    }
    
    // update
    func testRepository_updateTodo() async {
        // given
        let old = TodoEvent(self.dummyMakeParams)!
        self.stubSaveTodo([old])
        let repository = self.makeRepository()
        // when
        let params = TodoEditParams()
            |> \.name .~ old.name
            |> \.eventTagId .~ old.eventTagId
        let updated = try? await repository.updateTodoEvent(old.uuid, params)
        
        // then
        XCTAssertEqual(updated?.name, old.name)
        XCTAssertEqual(updated?.eventTagId, old.eventTagId)
        XCTAssertNil(updated?.time)
        XCTAssertNil(updated?.repeating)
    }
    
    // update and load
    func testRepository_loadTodoAfterUpdate() async throws {
        // given
        let repository = self.makeRepository()
        let old = try await repository.makeTodoEvent(self.dummyMakeParams)
        let params = TodoEditParams()
            |> \.name .~ "new name"
            |> \.eventTagId .~ "new tag"
            |> \.time .~ .at(.init(22, timeZone: "KST"))
        let _ = try await repository.updateTodoEvent(old.uuid, params)
        
        // when
        let events = try await repository.loadTodoEvents(in: self.dummyRange(0..<10)).values.first(where: { _ in true })
        
        // then
        XCTAssertEqual(events?.count, 1)
        let event = events?.first
        XCTAssertEqual(event?.name, "new name")
        XCTAssertEqual(event?.eventTagId, "new tag")
        XCTAssertEqual(event?.time, .at(.init(22, timeZone: "KST")))
    }
}


extension TodoLocalRepositoryImpleTests {
    
    private func makeDummyTodo(
        id: String,
        time: TimeInterval? = nil,
        from: TimeInterval? = nil,
        end: TimeInterval? = nil
    ) -> TodoEvent {
        let repeating = from
            .map {
                EventRepeating(
                    repeatingStartTime: .init($0, timeZone: "KST"),
                    repeatOption: EventRepeatingOptions.EveryDay()
                )
                |> \.repeatingEndTime .~ end.map { .init($0, timeZone: "KST") }
            }
        return TodoEvent(uuid: id, name: "name:\(id)")
            |> \.time .~ time.map { .at(.init($0, timeZone: "KST")) }
            |> \.repeating .~ repeating
    }
    
    private var dummyCurrentTodoAndHasTimes: [TodoEvent] {
        
        return [
            self.makeDummyTodo(id: "left_out_at", time: 20),
            self.makeDummyTodo(id: "left_out_range", time: 20, from: 20, end: 30),
            self.makeDummyTodo(id: "left_join", time: 30, from: 30, end: 60),
            self.makeDummyTodo(id: "contain_at", time: 70),
            self.makeDummyTodo(id: "contain_range", time: 60, from: 50, end: 100),
            self.makeDummyTodo(id: "right_join", time: 120, from: 120, end: 150),
            self.makeDummyTodo(id: "right_out_range", time: 151, from: 151, end: 200),
            self.makeDummyTodo(id: "right_out_at", time: 200),
            self.makeDummyTodo(id: "bigger_closed", time: 0, from: 0, end: 400),
            self.makeDummyTodo(id: "bigger_not_closed", time: 0, from: 0),
            self.makeDummyTodo(id: "bigger_right_join", time: 100, from: 100),
            self.makeDummyTodo(id: "not_join_bigger", time: 400, from: 400),
            self.makeDummyTodo(id: "current1"),
            self.makeDummyTodo(id: "current2")
        ]
    }
    
    // save todo(current or not) + load current todo
    func testRepository_loadCurrentTodos() {
        // given
        self.stubSaveTodo(self.dummyCurrentTodoAndHasTimes)
        let expect = expectation(description: "현재 할일 로드")
        let repositoty = self.makeRepository()
        
        // when
        let load = repositoty.loadCurrentTodoEvents()
        let currents = self.waitFirstOutput(expect, for: load, timeout: 1) ?? []
        
        // then
        let ids = currents.map { $0.uuid } |> Set.init
        XCTAssertEqual(ids, ["current1", "current2"])
    }
    
    // save todo(currnt or not) + load todos in range
    func testReposiotry_loadTodosInRange() {
        // given
        self.stubSaveTodo(self.dummyCurrentTodoAndHasTimes)
        let expect = expectation(description: "조회 범위에 해당하는 todo 로드")
        let repository = self.makeRepository()
        
        // when
        let load = repository.loadTodoEvents(in: 50..<150)
        let todos = self.waitFirstOutput(expect, for: load, timeout: 1) ?? []
        
        // then
        let ids = todos.map { $0.uuid } |> Set.init
        XCTAssertEqual(ids, [
//            "left_join",
            "contain_at", "contain_range",
            "right_join",
//            "bigger_closed",
//            "bigger_not_closed",
            "bigger_right_join"
        ])
    }
}

extension TodoLocalRepositoryImpleTests {
    
    // complete current todo -> no next event
    func testRepository_completeCurrentTodo() async {
        // given
        let origin = self.makeDummyTodo(id: "origin")
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.completeTodo(origin.uuid)
        
        // then
        XCTAssertEqual(result?.doneEvent.originEventId, "origin")
        XCTAssertNil(result?.nextRepeatingTodoEvent)
    }
    
    // complete not repeating todo -> no next event
    func testRepository_completeNotRepeatingTodo() async {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.completeTodo(origin.uuid)
        
        // then
        XCTAssertEqual(result?.doneEvent.originEventId, "origin")
        XCTAssertNil(result?.nextRepeatingTodoEvent)
    }
    
    // complete repeating todo -> has next evnet
    func testRepository_completeRepeatingEvent() async {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.completeTodo(origin.uuid)
        
        // then
        XCTAssertEqual(result?.doneEvent.originEventId, "origin")
        XCTAssertEqual(result?.nextRepeatingTodoEvent?.time, .at(.init(100 + 3600*24, timeZone: "KST")))
    }
    
    // complete reapting todo + next event time is over end time -> no next event
    func testRepository_completeRepeatingEventButNextTimeIsNotExists() async {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100, end: 200)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let result = try? await repository.completeTodo(origin.uuid)
        
        // then
        XCTAssertEqual(result?.doneEvent.originEventId, "origin")
        XCTAssertNil(result?.nextRepeatingTodoEvent)
    }
    
    // complete todo -> todo will updated
    func testRepository_whenAfterCompleteRepeatingTodo_originEventWillUpdated() async {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let _ = try? await repository.completeTodo(origin.uuid)
        let todos = try? await repository.loadTodoEvents(in: self.dummyRange(0..<24*3600+200)).values.first(where: { _ in true })
        
        // then
        let updated = todos?.first(where: { $0.uuid == origin.uuid })
        XCTAssertEqual(updated?.time, .at(.init(100+24*3600, timeZone: "KST")))
    }
    
    func testRepository_whenAfterNotRepeatingTodo_originEventWillRemoved() async {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let _ = try? await repository.completeTodo(origin.uuid)
        let todos = try? await repository.loadTodoEvents(in: self.dummyRange(0..<24*3600+200)).values.first(where: { _ in true })
        
        // then
        let updated = todos?.first(where: { $0.uuid == origin.uuid })
        XCTAssertNil(updated)
    }
}


extension TodoLocalRepositoryImpleTests {
    
    // replace repeating todo -> with next todo
    func testRepository_replaceRepeatingTodoOlyThisTime_andNextTodoExists() async {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let result = try? await repository.replaceRepeatingTodo(current: origin.uuid, to: params)
        let todos = try? await repository.loadTodoEvents(in: self.dummyRange(0..<24*3600+200)).values.first(where: { _ in true })
        
        // then
        XCTAssertNotEqual(result?.newTodoEvent.uuid, "origin")
        XCTAssertEqual(result?.newTodoEvent.name, params.name)
        XCTAssertEqual(result?.nextRepeatingTodoEvent?.time, .at(.init(100+24*3600, timeZone: "KST")))
        let updated = todos?.first(where: { $0.uuid == origin.uuid })
        XCTAssertEqual(updated?.time, .at(.init(100+24*3600, timeZone: "KST")))
    }
    
    // replace repeating todo -> without next todo
    func testRepository_replaceRepeatingTodoOnlyThisTime_andNextTodoNotExists() async {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100, end: 200)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let result = try? await repository.replaceRepeatingTodo(current: origin.uuid, to: params)
        let todos = try? await repository.loadTodoEvents(in: self.dummyRange(0..<24*3600+200)).values.first(where: { _ in true })
        
        // then
        XCTAssertNotEqual(result?.newTodoEvent.uuid, "origin")
        XCTAssertEqual(result?.newTodoEvent.name, params.name)
        XCTAssertNil(result?.nextRepeatingTodoEvent)
        let updated = todos?.first(where: { $0.uuid == origin.uuid })
        XCTAssertNil(updated)
    }
}
