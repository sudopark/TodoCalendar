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
    var spyEnvStorage: FakeEnvironmentStorage!
    
    override func setUpWithError() throws {
        self.fileName = "todos"
        try super.setUpWithError()
        self.cancelBag = .init()
        self.localStorage = .init(sqliteService: self.sqliteService)
        self.spyEnvStorage = .init()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.cancelBag = nil
        self.localStorage = nil
        self.spyEnvStorage = nil
    }
    
    private func makeRepository() -> TodoLocalRepositoryImple {
        return TodoLocalRepositoryImple(
            localStorage: self.localStorage,
            environmentStorage: self.spyEnvStorage
        )
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
        let repeating = EventRepeating(repeatingStartTime: 100, repeatOption: option)
            |> \.repeatingEndTime .~ 200
        return TodoMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ .custom("some")
            |> \.time .~ .period(
                0.0..<100.0
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
        XCTAssertEqual(event?.eventTagId, .custom("some"))
        XCTAssertEqual(event?.time, .period(0.0..<100.0))
        let repeatOption = event?.repeating?.repeatOption as? EventRepeatingOptions.EveryWeek
        XCTAssertEqual(repeatOption?.interval, 2)
        XCTAssertEqual(event?.repeating?.repeatingStartTime, 100)
        XCTAssertEqual(event?.repeating?.repeatingEndTime, 200)
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
    
    func testRepository_whenMakeOrUpdateTodo_udpateLatestEventTagId() async {
        // given
        let repository = self.makeRepository()
        let key = "latest_used_event_tag_id"
        
        // when
        let origin: String? = self.spyEnvStorage.load(key)
        let makeParams = self.dummyMakeParams |> \.eventTagId .~ .custom("tag1")
        let newTodo = try? await repository.makeTodoEvent(makeParams)
        let updatedeAfterMake: String? = self.spyEnvStorage.load(key)
        
        let updateParams = TodoEditParams()
            |> \.name .~ "new name"
            |> \.eventTagId .~ nil
        _ = try? await repository.updateTodoEvent(newTodo?.uuid ?? "", updateParams)
        let updatedAfterUpdate: String? = self.spyEnvStorage.load(key)
        
        // then
        XCTAssertEqual(origin, nil)
        XCTAssertEqual(updatedeAfterMake, "tag1")
        XCTAssertEqual(updatedAfterUpdate, nil)
    }
    
    // update and load
    func testRepository_loadTodoAfterUpdate() async throws {
        // given
        let repository = self.makeRepository()
        let old = try await repository.makeTodoEvent(self.dummyMakeParams)
        let params = TodoEditParams()
            |> \.name .~ "new name"
            |> \.eventTagId .~ .custom("new tag")
            |> \.time .~ .at(22)
        let _ = try await repository.updateTodoEvent(old.uuid, params)
        
        // when
        let events = try await repository.loadTodoEvents(in: self.dummyRange(0..<10)).values.first(where: { _ in true })
        
        // then
        XCTAssertEqual(events?.count, 1)
        let event = events?.first
        XCTAssertEqual(event?.name, "new name")
        XCTAssertEqual(event?.eventTagId, .custom("new tag"))
        XCTAssertEqual(event?.time, .at(22))
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
                    repeatingStartTime: $0,
                    repeatOption: EventRepeatingOptions.EveryDay()
                )
                |> \.repeatingEndTime .~ end
            }
        return TodoEvent(uuid: id, name: "name:\(id)")
            |> \.time .~ time.map { .at($0) }
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
            "left_join",
            "contain_at", "contain_range",
            "right_join",
            "bigger_closed",
            "bigger_not_closed",
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
        XCTAssertEqual(result?.nextRepeatingTodoEvent?.time, .at(100.0 + 3600*24))
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
        XCTAssertEqual(updated?.time, .at(100.0+24*3600))
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
        XCTAssertEqual(result?.nextRepeatingTodoEvent?.time, .at(100.0+24*3600))
        let updated = todos?.first(where: { $0.uuid == origin.uuid })
        XCTAssertEqual(updated?.time, .at(100.0+24*3600))
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


// MARK: load todo in period + all day

extension TodoLocalRepositoryImpleTests {
    
    // allday + 2023.07.24~07.26 + kst 이벤트가 있고 이를
    // udt로 조회, pdt로 조회, t14로 조회, t-12로 조회
    
    private func dummyAllDayLoadRange(timeZone: TimeZone) -> Range<TimeInterval> {
        return try! TimeInterval.range(
            from: "2023-07-23 00:00:00",
            to: "2023-07-25 23:59:59",
            in: timeZone
        )
    }
    
    private var dummyParams: TodoMakeParams {
        let timeZone = TimeZone(abbreviation: "KST")!
        let secondsFromGMT = timeZone.secondsFromGMT() |> TimeInterval.init
        let range = self.dummyAllDayLoadRange(timeZone: timeZone)
        return TodoMakeParams()
            |> \.name .~ "all-day"
            |> \.time .~ .allDay(range, secondsFromGMT: secondsFromGMT)
    }
    
    private func makeRepositoryWithSaveAllDayTodo() async throws -> TodoLocalRepositoryImple {
        let repository = self.makeRepository()
        _ = try await repository.makeTodoEvent(self.dummyParams)
        return repository
    }
    
    func testRepository_loadAllDayEvent_withOtherTimeZones() async throws {
        // given
        let repository = try await self.makeRepositoryWithSaveAllDayTodo()
        let timeZones: [TimeZone] = [
            .init(abbreviation: "UTC")!, .init(abbreviation: "KST")!, .init(abbreviation: "PDT")!,
            .init(secondsFromGMT: 14*3600)!, .init(secondsFromGMT: -12*3600)!
        ]
        
        // when
        let ranges = timeZones.map { self.dummyAllDayLoadRange(timeZone: $0) }
        var todos: [TodoEvent?] = []
        try await ranges.asyncForEach { range in
            let todo = try await repository.loadTodoEvents(in: range).values.first(where: { _ in true })
            todos.append(todo?.first)
        }
        
        // then
        let todoNames = todos.map { $0?.name }
        XCTAssertEqual(todoNames, Array(repeating: "all-day", count: timeZones.count))
    }
}


extension TimeInterval {
    
    static func range(from: String, to: String, in timeZone: TimeZone) throws -> Range<TimeInterval> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = timeZone
        
        let start = try formatter.date(from: from).unwrap()
        let end = try formatter.date(from: to).unwrap()
        return (start.timeIntervalSince1970..<end.timeIntervalSince1970)
    }
}
