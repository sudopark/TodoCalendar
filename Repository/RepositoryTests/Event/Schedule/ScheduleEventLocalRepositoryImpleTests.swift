//
//  ScheduleEventLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/05/27.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import AsyncFlatMap
import UnitTestHelpKit

@testable import Repository


class ScheduleEventLocalRepositoryImpleTests: BaseLocalTests, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    var localStorage: ScheduleEventLocalStorage!
    
    override func setUpWithError() throws {
        self.fileName = "schedules"
        try super.setUpWithError()
        self.cancelBag = .init()
        self.localStorage = .init(sqliteService: self.sqliteService)
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.localStorage = nil
        try super.tearDownWithError()
    }
    
    private func makeRepository() -> ScheduleEventLocalRepositoryImple {
        return ScheduleEventLocalRepositoryImple(localStorage: self.localStorage)
    }
}

extension ScheduleEventLocalRepositoryImpleTests {
    
    private func dummyRange(_ range: Range<Int>) -> Range<TimeInterval> {
        let oneDay: TimeInterval = 24 * 3600
        return TimeInterval(range.lowerBound)*oneDay
                ..<
                TimeInterval(range.upperBound)*oneDay
    }
    
    private var dummyMakeParams: ScheduleMakeParams {
        let option = EventRepeatingOptions.EveryDay()
        let repeating = EventRepeating(repeatingStartTime: 100.0, repeatOption: option)
            |> \.repeatingEndTime .~ 200.0
        return ScheduleMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ "some"
            |> \.time .~ .at(100)
            |> \.showTurn .~ true
            |> \.repeating .~ repeating
    }
    
    // make and load
    func testRepository_makeAndLoadNewEvent() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let new = try? await repository.makeScheduleEvent(params)
        let loadEvents = try? await repository.loadScheduleEvents(in: self.dummyRange(0..<10))
            .values.first(where: { _ in true })
        
        // then
        XCTAssertNotNil(new)
        XCTAssertEqual(new?.name, params.name)
        XCTAssertEqual(new?.eventTagId, params.eventTagId)
        XCTAssertEqual(new?.time, params.time)
        XCTAssertEqual(new?.repeating, params.repeating)
        XCTAssertEqual(new?.showTurn, params.showTurn)
        let event = loadEvents?.first(where: { $0.name == params.name })
        XCTAssertNotNil(event)
    }
    
    // update and load
    func testRepository_updateAndLoad() async {
        // given
        let repository = self.makeRepository()
        let origin = try? await repository.makeScheduleEvent(self.dummyMakeParams)
        
        // when
        let params = ScheduleEditParams()
            |> \.time .~ .at(0)
        let updated = try? await repository.updateScheduleEvent(origin?.uuid ?? "", params)
        let loadedEvents = try? await repository.loadScheduleEvents(in: self.dummyRange(0..<10))
            .values.first(where: { _ in true })
        
        // then
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.name, origin?.name)
        XCTAssertEqual(updated?.time, .at(0))
        XCTAssertEqual(updated?.repeating, nil)
        
        let event = loadedEvents?.first(where: { $0.uuid == origin?.uuid })
        XCTAssertNotNil(event)
    }
}


extension ScheduleEventLocalRepositoryImpleTests {
    
    private func makeDummySchedule(
        id: String,
        time: TimeInterval,
        from: TimeInterval? = nil,
        end: TimeInterval? = nil
    ) -> ScheduleEvent {
        let repeating = from
            .map {
                EventRepeating(
                    repeatingStartTime: $0,
                    repeatOption: EventRepeatingOptions.EveryDay()
                )
                |> \.repeatingEndTime .~ end
            }
        return ScheduleEvent(uuid: id, name: "name:\(id)", time: .at(time))
            |> \.repeating .~ repeating
            |> \.showTurn .~ true
    }
    
    private var dummyScheduleEvents: [ScheduleEvent] {
        
        return [
            self.makeDummySchedule(id: "left_out_at", time: 20),
            self.makeDummySchedule(id: "left_out_range", time: 20, from: 20, end: 30),
            self.makeDummySchedule(id: "left_join", time: 30, from: 30, end: 60),
            self.makeDummySchedule(id: "contain_at", time: 70),
            self.makeDummySchedule(id: "contain_range", time: 60, from: 50, end: 100),
            self.makeDummySchedule(id: "right_join", time: 120, from: 120, end: 150),
            self.makeDummySchedule(id: "right_out_range", time: 151, from: 151, end: 200),
            self.makeDummySchedule(id: "right_out_at", time: 200),
            self.makeDummySchedule(id: "bigger_closed", time: 0, from: 0, end: 400),
            self.makeDummySchedule(id: "bigger_not_closed", time: 0, from: 0),
            self.makeDummySchedule(id: "bigger_right_join", time: 100, from: 100),
            self.makeDummySchedule(id: "not_join_bigger", time: 400, from: 400),
        ]
    }
    
    // load todo in range
    private func stubSaveEvents(_ events: [ScheduleEvent]) {
        let expect = expectation(description: "wait-save")
        
        let saving: AsyncFlatMapPublisher<Void, Error, Void> = Publishers.create {
            return try await self.localStorage.updateScheduleEvents(events)
        }
        let _ = self.waitFirstOutput(expect, for: saving, timeout: 1)
    }
    
    func testReposiotry_loadEventsInRange() {
        // given
        self.stubSaveEvents(self.dummyScheduleEvents)
        let expect = expectation(description: "조회 범위에 해당하는 schedule event 로드")
        let repository = self.makeRepository()
        
        // when
        let range = 50.0..<150.0
        let load = repository.loadScheduleEvents(in: range)
        let events = self.waitFirstOutput(expect, for: load, timeout: 1) ?? []
        
        // then
        let ids = events.map { $0.uuid } |> Set.init
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


extension ScheduleEventLocalRepositoryImpleTests {
    
    // exclude
    func testRepository_excludeRepeatingEvent() async {
        // given
        let repository = self.makeRepository()
        let origin = try? await repository.makeScheduleEvent(self.dummyMakeParams)
        
        // when
        let time = EventTime.at(100)
        let newParams = self.dummyMakeParams
            |> \.time .~ .at(100)
            |> \.name .~ "new name"
        let result = try? await repository.excludeRepeatingEvent(
            origin?.uuid ?? "",
            at: time, asNew: newParams
        )
        let loadedEvents = try? await repository.loadScheduleEvents(in: self.dummyRange(0..<10))
            .values.first(where: { _ in true })
        
        // then
        XCTAssertNotNil(result)
        XCTAssertNotEqual(result?.newEvent.uuid, result?.originEvent.uuid)
        XCTAssertEqual(result?.newEvent.name, "new name")
        XCTAssertEqual(result?.newEvent.time, .at(100))
        XCTAssertEqual(result?.newEvent.repeatingTimeToExcludes, [])
        XCTAssertEqual(result?.originEvent.name, origin?.name)
        XCTAssertEqual(result?.originEvent.repeatingTimeToExcludes, [
            EventTime.at(100).customKey
        ])
        
        let loadedOrigin = loadedEvents?.first(where: { $0.uuid == origin?.uuid })
        let new = loadedEvents?.first(where: { $0.uuid == result?.newEvent.uuid })
        XCTAssertNotNil(new)
        XCTAssertEqual(loadedOrigin?.repeatingTimeToExcludes, result?.originEvent.repeatingTimeToExcludes)
    }
}
