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
import Extensions
import AsyncFlatMap
import UnitTestHelpKit
import SQLiteService

@testable import Repository


class TodoLocalRepositoryImpleTests: BaseLocalTests, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    var localStorage: TodoLocalStorageImple!
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
    
    func makeRepository() -> any TodoEventRepository {
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
    
    var dummyMakeParams: TodoMakeParams {
        let option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
            |> \.interval .~ 2
        let repeating = EventRepeating(repeatingStartTime: 100, repeatOption: option)
            |> \.repeatingEndOption .~ .until(200)
        return TodoMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ .custom("some")
            |> \.time .~ .period(
                0.0..<100.0
            )
            |> \.repeating .~ pure(repeating)
            |> \.notificationOptions .~ [.before(seconds: 100), .atTime]
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
    
    func testRepository_makeNewTodoWithRepeating() async {
        // given
        let kst = TimeZone(abbreviation: "KST")!
        
        func parameterizeTest(_ option: EventRepeatingOption) async {
            // given
            let repository = self.makeRepository()
            
            // when
            let repeating = EventRepeating(repeatingStartTime: 100, repeatOption: option)
                |> \.repeatingEndOption .~ .until(200)
            let params = self.dummyMakeParams |> \.repeating .~ repeating
            let todo = try? await repository.makeTodoEvent(params)
            
            // then
            XCTAssertEqual(todo?.name, "new")
            XCTAssertEqual(todo?.eventTagId, .custom("some"))
            XCTAssertEqual(todo?.time, .period(0.0..<100.0))
            XCTAssertEqual(todo?.repeating?.repeatingStartTime, 100)
            XCTAssertEqual(todo?.repeating?.repeatOption.compareHash, option.compareHash)
            XCTAssertEqual(todo?.repeating?.repeatingEndOption?.endTime, 200)
            XCTAssertEqual(todo?.notificationOptions, [.before(seconds: 100), .atTime])
        }
        
        // when
        let days3 = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        await parameterizeTest(days3)
        
        let week3 = EventRepeatingOptions.EveryWeek(kst)
            |> \.interval .~ 3
            |> \.dayOfWeeks .~ [.friday, .saturday]
        await parameterizeTest(week3)
        
        let monthWithDay = EventRepeatingOptions.EveryMonth(timeZone: kst)
            |> \.interval .~ 3
            |> \.selection .~ .days([1, 2, 3])
        await parameterizeTest(monthWithDay)
        
        let monthWithWeekOrdinal = EventRepeatingOptions.EveryMonth(timeZone: kst)
            |> \.interval .~ 3
            |> \.selection .~ .week([.seq(1), .last], [.monday, .saturday])
        await parameterizeTest(monthWithWeekOrdinal)
        
        let year3 = EventRepeatingOptions.EveryYear(timeZone: kst)
            |> \.interval .~ 10
            |> \.months .~ [.april, .august]
            |> \.weekOrdinals .~ [.last, .seq(1)]
            |> \.dayOfWeek .~ [.friday, .saturday]
        await parameterizeTest(year3)
        
        let yearSomeDay = EventRepeatingOptions.EveryYearSomeDay(kst, 12, 20)
            |> \.interval .~ 3
        await parameterizeTest(yearSomeDay)
        
        let lunarEveryYEar = EventRepeatingOptions.LunarCalendarEveryYear(kst, 4, 11)
        await parameterizeTest(lunarEveryYEar)
    }
    
    func stubSaveTodo(
        _ todos: [TodoEvent]
    ) {
        let expect = expectation(description: "wait-save")
        typealias Detail = EventDetailDataTable
        
        let details = todos.map { EventDetailData($0.uuid) }
        let saving: AsyncFlatMapPublisher<Void, Error, Void> = Publishers.create {
            try await self.localStorage.updateTodoEvents(todos)
            try await self.sqliteService.async.run { db in
                try db.insert(Detail.self, entities: details)
            }
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
        XCTAssertEqual(event?.repeating?.repeatingEndOption?.endTime, 200)
        XCTAssertEqual(event?.notificationOptions, [.before(seconds: 100), .atTime])
        XCTAssertNotNil(event?.creatTimeStamp)
    }
    
    // update
    func testRepository_updateTodo() async {
        // given
        let old = TodoEvent(self.dummyMakeParams)!
        self.stubSaveTodo([old])
        let repository = self.makeRepository()
        // when
        let params = TodoEditParams(.put)
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
        let params = TodoEditParams(.put)
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
    
    func testReposiotry_loadTodoAfterPatchTodo() async throws {
        // given
        let repository = self.makeRepository()
        let old = try await repository.makeTodoEvent(self.dummyMakeParams)
        let params = TodoEditParams(.patch) |> \.name .~ "new name"
        let _ = try await repository.updateTodoEvent(old.uuid, params)
        
        // when
        let events = try await repository.loadTodoEvents(in: self.dummyRange(0..<10)).firstValue(with: 10)
        
        // then
        XCTAssertEqual(events?.count, 1)
        let event = events?.first
        XCTAssertEqual(event?.name, "new name")
        XCTAssertEqual(event?.eventTagId, .custom("some"))
        XCTAssertEqual(event?.time, .period(0.0..<100.0))
        XCTAssertNotNil(event?.repeating)
        XCTAssertEqual(event?.notificationOptions.count, 2)
    }
    
    func testReposiotry_loadUncompletedTodos() async throws {
        // given
        let now = Date()
        let repository = self.makeRepository()
        func stubTodos() async throws {
            let pastTodos = (-4..<0).map { int in
                return TodoEvent(uuid: "id:\(int)", name: "todo:\(int)")
                    |> \.time .~ .at(now.timeIntervalSince1970 - TimeInterval(int+100))
            }
            let nowAndFutureTodos = (0..<4).map { int in
                return TodoEvent(uuid: "id:\(int)", name: "todo:\(int)")
                    |> \.time .~ .at(now.timeIntervalSince1970 + TimeInterval(int+100))
            }
            try await self.localStorage.updateTodoEvents(pastTodos + nowAndFutureTodos)
        }
        try await stubTodos()
        
        // when
        let uncompletedTodos = try await repository.loadUncompletedTodos().firstValue(with: 100)
        
        
        // then
        let uncompletedTodoIds = uncompletedTodos?.map(\.uuid)
        XCTAssertEqual(uncompletedTodoIds, (-4..<0).map{ "id:\($0)" })
    }
}


// MARK: - test remove

extension TodoLocalRepositoryImpleTests {
    
   func makeRepositoryWithStubTodo(
        _ todo: TodoEvent
    ) async throws -> any TodoEventRepository {
        let repository = self.makeRepository()
        try await self.localStorage.saveTodoEvent(todo)
        let detail = EventDetailData(todo.uuid)
        try await self.sqliteService.async.run { db in
            try db.insertOne(EventDetailDataTable.self, entity: detail, shouldReplace: true)
        }
        return repository
    }
 
    func testReposiotry_removeTodo_withoutNextRepeating() async throws {
        // given
        let todo = self.makeDummyTodo(id: "some")
        let repository = try await self.makeRepositoryWithStubTodo(todo)
        
        // when
        let result = try await repository.removeTodo(todo.uuid, onlyThisTime: false)
        
        // then
        XCTAssertNil(result.nextRepeatingTodo)
        
        let detail = try await self.eventDetail(todo.uuid)
        XCTAssertNil(detail)
    }
    
    func testRepository_removeTodo_withNextRepeating() async throws {
        // given
        let todo = self.makeDummyTodo(id: "some", time: 0, from: 0)
        let repository = try await self.makeRepositoryWithStubTodo(todo)
        
        // when
        let result = try await repository.removeTodo(todo.uuid, onlyThisTime: true)
        
        // then
        XCTAssertNotNil(result.nextRepeatingTodo)
        
        let detail = try await self.eventDetail(todo.uuid)
        XCTAssertNotNil(detail)
    }
    
    func testRepository_removeRepeatingTodo() async throws {
        // given
        let todo = self.makeDummyTodo(id: "some", time: 0, from: 0)
        let repository = try await self.makeRepositoryWithStubTodo(todo)
        
        // when
        let result = try await repository.removeTodo(todo.uuid, onlyThisTime: false)
        
        // then
        XCTAssertNil(result.nextRepeatingTodo)
    }
}

extension TodoLocalRepositoryImpleTests {
    
    func makeDummyTodo(
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
                |> \.repeatingEndOption .~ end.map { .until($0) }
            }
        return TodoEvent(uuid: id, name: "name:\(id)")
            |> \.time .~ time.map { .at($0) }
            |> \.repeating .~ repeating
            |> \.notificationOptions .~ [.allDay9AMBefore(seconds: 100)]
            |> \.creatTimeStamp .~ 100
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
    
    private func eventDetail(_ id: String) async throws -> EventDetailData? {
        typealias Detail = EventDetailDataTable
        return try await self.sqliteService.async.run { db in
            let query = Detail.selectAll { $0.uuid == id }
            return try db.loadOne(Detail.self, query: query)
        }
    }
    
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
        XCTAssertEqual(result?.doneEvent.notificationOptions, [.allDay9AMBefore(seconds: 100)])
        
        XCTAssertNotNil(result?.doneTodoEventDetail)
        XCTAssertEqual(result?.doneTodoEventDetail?.eventId, result?.doneEvent.uuid)
        let detail = try? await eventDetail(origin.uuid)
        XCTAssertNil(detail)
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
        
        XCTAssertNotNil(result?.doneTodoEventDetail)
        XCTAssertEqual(result?.doneTodoEventDetail?.eventId, result?.doneEvent.uuid)
        let detail = try? await eventDetail(origin.uuid)
        XCTAssertNil(detail)
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
        XCTAssertEqual(result?.nextRepeatingTodoEvent?.creatTimeStamp, 100)
        
        XCTAssertNotNil(result?.doneTodoEventDetail)
        XCTAssertEqual(result?.doneTodoEventDetail?.eventId, result?.doneEvent.uuid)
        let detail = try? await eventDetail(origin.uuid)
        XCTAssertNil(detail)
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
        XCTAssertNotNil(result?.newTodoEvent.creatTimeStamp)
        XCTAssertEqual(result?.newTodoEvent.name, params.name)
        XCTAssertEqual(result?.nextRepeatingTodoEvent?.time, .at(100.0+24*3600))
        XCTAssertEqual(result?.nextRepeatingTodoEvent?.creatTimeStamp, 100)
        let updated = todos?.first(where: { $0.uuid == origin.uuid })
        XCTAssertEqual(updated?.time, .at(100.0+24*3600))
        
        let detail = try? await self.eventDetail("origin")
        XCTAssertNotNil(detail)
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
        XCTAssertNotNil(result?.newTodoEvent)
        XCTAssertEqual(result?.newTodoEvent.name, params.name)
        XCTAssertNil(result?.nextRepeatingTodoEvent)
        let updated = todos?.first(where: { $0.uuid == origin.uuid })
        XCTAssertNil(updated)
        
        let detail = try? await self.eventDetail("origin")
        XCTAssertNil(detail)
    }
}

extension TodoLocalRepositoryImpleTests {
    
    func testRepository_skipRepeatingTodo() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100, end: nil)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let next = try await repository.skipRepeatingTodo("origin")
        
        // then
        XCTAssertEqual(next.time?.lowerBoundWithFixed, 100 + 24 * 3600)
    }
    
    func testRepository_whenSkipNotRepeatingTodo_error() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin")
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        var reason: (any Error)?
        do {
            let _ = try await repository.skipRepeatingTodo("origin")
        } catch let err {
            reason = err
        }
        
        // then
        XCTAssertEqual(
            (reason as? RuntimeError)?.key,
            ClientErrorKeys.notARepeatingEvent.rawValue
        )
    }
    
    func testRepository_whenSkipLastRepeatingTodo_error() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100, end: 200)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        var reason: (any Error)?
        do {
            let _ = try await repository.skipRepeatingTodo("origin")
        } catch let err {
            reason = err
        }
        
        // then
        XCTAssertEqual(
            (reason as? RuntimeError)?.key,
            ClientErrorKeys.repeatingIsEnd.rawValue
        )
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
    
    private func makeRepositoryWithSaveAllDayTodo() async throws -> any TodoEventRepository {
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
    
    func testRepository_loadTodoById() async throws {
        // given
        let todo = TodoEvent(uuid: "dummy", name: "some")
        let repository = try await self.makeRepositoryWithStubTodo(todo)
        
        // when
        let loadedTodo = try await repository.todoEvent(todo.uuid).firstValue(with: 100)
        
        // then
        XCTAssertNotNil(loadedTodo)
    }
}


extension TodoLocalRepositoryImpleTests {
    
    func makeRepositoryWithDoneEvents() async throws -> any TodoEventRepository {
        let dones: [DoneTodoEvent] = (0..<10).map { int in
            return .init(
                uuid: "id:\(int)", name: "done:\(int)",
                originEventId: "origin-\(int)",
                doneTime: Date(timeIntervalSince1970: TimeInterval(int))
            )
        }
        try await self.localStorage.updateDoneTodos(dones)
        let details = dones.map { EventDetailData($0.uuid) }
        try await self.sqliteService.async.run { db in
            try db.insert(DoneTodoEventDetailTable.self, entities: details)
        }
        return self.makeRepository()
    }
    
    // done todo paging -> [9, 8, 7], [6, 5, 4], [3, 2, 1], [0], []
    func testRepository_loadDoneTodosWithPaging() async throws {
        // given
        let repository = try await self.makeRepositoryWithDoneEvents()
        
        // when
        let page1 = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: nil, size: 3)
        )
        let page2 = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: page1.last?.doneTime.timeIntervalSince1970, size: 3)
        )
        let page3 = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: page2.last?.doneTime.timeIntervalSince1970, size: 3)
        )
        let page4 = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: page3.last?.doneTime.timeIntervalSince1970, size: 3)
        )
        let page5 = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: page4.last?.doneTime.timeIntervalSince1970, size: 3)
        )
        
        // then
        XCTAssertEqual(page1.map { $0.uuid }, [9, 8, 7].map { "id:\($0)" })
        XCTAssertEqual(page2.map { $0.uuid }, [6, 5, 4].map { "id:\($0)" })
        XCTAssertEqual(page3.map { $0.uuid }, [3, 2, 1].map { "id:\($0)" })
        XCTAssertEqual(page4.map { $0.uuid }, [0].map { "id:\($0)" })
        XCTAssertEqual(page5.isEmpty, true)
    }
    
    private func doneTodoEventDetails() async throws -> [EventDetailData] {
        return try await self.sqliteService.async.run { db in
            let query = DoneTodoEventDetailTable.selectAll()
            return try db.load(DoneTodoEventDetailTable.self, query: query)
        }
    }
    
    // remove done todo past than 3
    func testRepository_removeDoneTodosPastThan3() async throws {
        // given
        let repository = try await self.makeRepositoryWithDoneEvents()
        let donesBeforeRemove = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: nil, size: 20)
        )
        
        // when
        try await repository.removeDoneTodos(.pastThan(3))
        let donesAfterRemove = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: nil, size: 20)
        )
        
        // then
        XCTAssertEqual(donesBeforeRemove.map { $0.uuid }, (0..<10).reversed().map { "id:\($0)"})
        XCTAssertEqual(donesAfterRemove.map { $0.uuid }, (3..<10).reversed().map { "id:\($0)"})
        
        let doneDetails = try await doneTodoEventDetails()
        XCTAssertEqual(
            doneDetails.map { $0.eventId }.sorted(),
            (3..<10).map { "id:\($0)"}
        )
    }
    
    // remove all done todo
    func testRepository_removeAllDoneTodos() async throws {
        // given
        let repository = try await self.makeRepositoryWithDoneEvents()
        let donesBeforeRemove = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: nil, size: 20)
        )
        
        // when
        try await repository.removeDoneTodos(.all)
        let donesAfterRemove = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: nil, size: 20)
        )
        
        // then
        XCTAssertEqual(donesBeforeRemove.map { $0.uuid }, (0..<10).reversed().map { "id:\($0)"})
        XCTAssertEqual(donesAfterRemove.map { $0.uuid }, [])
        
        let details = try await self.doneTodoEventDetails()
        XCTAssertEqual(details.isEmpty, true)
    }
    
    // revert done todo
    func testRepository_revertDoneTodo() async throws {
        // given
        let repository = try await self.makeRepositoryWithDoneEvents()
        let donesBeforeRevert = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: nil, size: 20)
        )
        
        // when
        let result = try await repository.revertDoneTodo("id:4")
        let donesAfterRevert = try await repository.loadDoneTodoEvents(
            .init(cursorAfter: nil, size: 20)
        )
        
        // then
        let todo = result.revertTodo
        XCTAssertNotEqual(todo.uuid, "origin-4")
        XCTAssertNotNil(todo.creatTimeStamp)
        XCTAssertEqual(
            donesBeforeRevert.map { $0.uuid },
            (0..<10).reversed().map { "id:\($0)"}
        )
        XCTAssertEqual(
            donesAfterRevert.map { $0.uuid },
            (0..<10).filter { $0 != 4 }.reversed().map { "id:\($0)"}
        )
        
        let doneDetail = try await self.doneTodoEventDetails()
            .first(where: { $0.eventId == "id:4" })
        XCTAssertNil(doneDetail)
        let eventDetail = try await self.eventDetail(todo.uuid)
        XCTAssertNotNil(eventDetail)
    }
}

extension TodoLocalRepositoryImpleTests {
    
    func makeRepositoryWithDoneFromRepeatingTodo() async throws -> any TodoEventRepository {
        let doneAtEvent = DoneTodoEvent(
            uuid: "done_at", name: "done_at", originEventId: "repeating_origin", doneTime: .init()
        )
        |> \.eventTime .~ .at(100)
        let doneWithPeriodEvent = DoneTodoEvent(
            uuid: "done_period", name: "done_period", originEventId: "repeating_origin", doneTime: .init()
        )
        |> \.eventTime .~ .period(0..<100)
        let doneWithAlldayEvent = DoneTodoEvent(
            uuid: "done_allday", name: "done_allday", originEventId: "repeating_origin", doneTime: .init()
        )
        |> \.eventTime .~ .allDay(0..<100, secondsFromGMT: 0)
        
        let doneWithoutTime = DoneTodoEvent(
            uuid: "done", name: "done", originEventId: "not_repeating", doneTime: .init()
        )
        
        try await self.localStorage.updateDoneTodos([
            doneAtEvent, doneWithPeriodEvent, doneWithAlldayEvent, doneWithoutTime
        ])
        
        let todo = TodoEvent(uuid: "todo", name: "todo")
        try await self.localStorage.updateTodoEvent(todo)
        return self.makeRepository()
    }
    
    func testRepository_toggleTodo_complete() async throws {
        // given
        let repository = try await self.makeRepositoryWithDoneFromRepeatingTodo()
        
        // when
        let result = try await repository.toggleTodo("todo")
        
        // then
        let completed = result?.completed
        XCTAssertEqual(completed?.name, "todo")
        XCTAssertEqual(completed?.originEventId, "todo")
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

private extension TodoToggleResult {
    
    var completed: DoneTodoEvent? {
        guard case .completed(let done) = self else { return nil }
        return done
    }
    
    var reverted: TodoEvent? {
        guard case .reverted(let todo) = self else { return nil }
        return todo
    }
}
