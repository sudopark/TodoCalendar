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
    
    private func dummyRange(_ range: Range<Int>) -> Range<TimeStamp> {
        let oneDay: TimeInterval = 24 * 3600
        return TimeStamp(TimeInterval(range.lowerBound) * oneDay, timeZone: "KST")
            ..<
            TimeStamp(TimeInterval(range.upperBound) * oneDay, timeZone: "KST")
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
    
    // save todo(current or not) + load current todo
    
    // save todo(currnt or not) + load todos in range
}

extension TodoLocalRepositoryImpleTests {
    
    // complete current todo -> no next event
    
    // complete not repeating todo -> no next event
    
    // complete repeating todo -> has next evnet
    
    // complete reapting todo + next event time is over end time -> no next event
    
    // complete todo -> todo will updated
}


extension TodoLocalRepositoryImpleTests {
    
    // replace repeating todo -> with next todo
    
    // replace repeating todo -> without next todo
    
    // replace repeating todo -> origin todo will updated
}
