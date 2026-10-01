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
import SQLiteService

@testable import Repository


class ScheduleEventLocalRepositoryImpleTests: BaseLocalTests, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    var localStorage: ScheduleEventLocalStorageImple!
    var spyEnvStorage: FakeEnvironmentStorage!
    
    override func setUpWithError() throws {
        self.fileName = "schedules"
        try super.setUpWithError()
        self.cancelBag = .init()
        self.localStorage = .init(sqliteService: self.sqliteService)
        self.spyEnvStorage = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.localStorage = nil
        self.spyEnvStorage = nil
        try super.tearDownWithError()
    }
    
    func makeRepository() -> any ScheduleEventRepository {
        return ScheduleEventLocalRepositoryImple(
            localStorage: self.localStorage,
            environmentStorage: self.spyEnvStorage
        )
    }
}

extension ScheduleEventLocalRepositoryImpleTests {
    
    private func dummyRange(_ range: Range<Int>) -> Range<TimeInterval> {
        let oneDay: TimeInterval = 24 * 3600
        return TimeInterval(range.lowerBound)*oneDay
                ..<
                TimeInterval(range.upperBound)*oneDay
    }
    
    var dummyMakeParams: ScheduleMakeParams {
        let option = EventRepeatingOptions.EveryDay()
        let repeating = EventRepeating(repeatingStartTime: 100.0, repeatOption: option)
            |> \.repeatingEndOption .~ .until(200.0)
        return ScheduleMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ .custom("some")
            |> \.time .~ .at(100)
            |> \.showTurn .~ true
            |> \.repeating .~ pure(repeating)
            |> \.notificationOptions .~ [.before(seconds: 100), .atTime]
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
        XCTAssertEqual(new?.notificationOptions, [.before(seconds: 100), .atTime])
    }
    
    // update and load
    func testRepository_updateAndLoad() async {
        // given
        let repository = self.makeRepository()
        let origin = try? await repository.makeScheduleEvent(self.dummyMakeParams)
        
        // when
        let params = SchedulePutParams()
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
    
    typealias Detail = EventDetailDataTable
    
    func makeRepositoryWithStubSchedule(
        _ schedule: ScheduleEvent
    ) async throws -> any ScheduleEventRepository {
        let repository = self.makeRepository()
        try await self.localStorage.saveScheduleEvent(schedule)
        let detail = EventDetailData(schedule.eventId)
        try await self.sqliteService.async.run { db in
            try db.insertOne(Detail.self, entity: detail, shouldReplace: false)
        }
        return repository
    }
    
    private func scheduleDetail(_ id: String) async throws -> EventDetailData? {
        return try await self.sqliteService.async.run { db in
            let query = Detail.selectAll { $0.uuid == id }
            return try db.loadOne(Detail.self, query: query)
        }
    }
 
    func testReposiotry_removeSchedule_withoutNextRepeating() async throws {
        // given
        let schedule = self.makeDummySchedule(id: "some", time: 0)
        let repository = try await self.makeRepositoryWithStubSchedule(schedule)
        
        // when
        let result = try await repository.removeEvent(schedule.uuid, onlyThisTime: nil)
        
        // then
        XCTAssertNil(result.nextRepeatingEvnet)
        let detail = try? await scheduleDetail("some")
        XCTAssertNil(detail)
    }
    
    func testRepository_removeSchedule_withNextRepeating() async throws {
        // given
        let schedule = self.makeDummySchedule(id: "some", time: 0, from: 0)
        let repository = try await self.makeRepositoryWithStubSchedule(schedule)
        
        // when
        let result = try await repository.removeEvent(schedule.uuid, onlyThisTime: .at(0))
        
        // then
        XCTAssertNotNil(result.nextRepeatingEvnet)
        let detail = try? await scheduleDetail("some")
        XCTAssertNotNil(detail)
    }
    
    func testRepository_removeRepeatingSchedule() async throws {
        // given
        let schedule = self.makeDummySchedule(id: "some", time: 0, from: 0)
        let repository = try await self.makeRepositoryWithStubSchedule(schedule)
        
        // when
        let result = try await repository.removeEvent(schedule.uuid, onlyThisTime: nil)
        
        // then
        XCTAssertNil(result.nextRepeatingEvnet)
        let detail = try? await scheduleDetail("some")
        XCTAssertNil(detail)
    }
}

extension ScheduleEventLocalRepositoryImpleTests {
    
    func makeDummySchedule(
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
                |> \.repeatingEndOption .~ end.map { .until($0) }
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
        let _ = self.waitFirstOutput(expect, for: saving)
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
    
    var dummyRepeatingOrigin: ScheduleEvent {
        let option = EventRepeatingOptions.EveryDay()
        let repeating = EventRepeating(repeatingStartTime: 0, repeatOption: option)
        return ScheduleEvent(uuid: "repeating", name: "origin", time: .at(0))
            |> \.repeating .~ repeating
    }
    
    func testRepository_brachNewRepeatingEventFromOriginRepeating() async throws {
        // given
        let reposiotry = self.makeRepository()
        let origin = self.dummyRepeatingOrigin
        try await self.localStorage.saveScheduleEvent(origin)
        
        // when
        let params = SchedulePutParams()
        |> \.name .~ "new"
        |> \.time .~ .at(100)
        |> \.repeating .~ pure(EventRepeating(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()))
        let result = try await reposiotry.branchNewRepeatingEvent(
            "repeating", fromTime: 100, params
        )
        
        // then
        XCTAssertEqual(result.reppatingEndOriginEvent.name, "origin")
        XCTAssertEqual(result.reppatingEndOriginEvent.time, .at(0))
        XCTAssertEqual(result.reppatingEndOriginEvent.repeating?.repeatingStartTime, 0)
        XCTAssertEqual(result.reppatingEndOriginEvent.repeating?.repeatOption.compareHash, EventRepeatingOptions.EveryDay().compareHash)
        XCTAssertEqual(result.reppatingEndOriginEvent.repeating?.repeatingEndOption?.endTime, 100)
        
        XCTAssertEqual(result.newRepeatingEvent.name, "new")
        XCTAssertEqual(result.newRepeatingEvent.time, .at(100))
        XCTAssertEqual(result.newRepeatingEvent.repeating?.repeatingStartTime, 100)
        XCTAssertEqual(result.newRepeatingEvent.repeating?.repeatOption.compareHash, EventRepeatingOptions.EveryDay().compareHash)
        XCTAssertEqual(result.newRepeatingEvent.repeating?.repeatingEndOption?.endTime, nil)
    }
    
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


extension ScheduleEventLocalRepositoryImpleTests {
    
    private func dummyWeeklyRepeating(_ endOption: EventRepeating.RepeatEndOption) -> EventRepeating {
        var option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
        option.interval = 2
        option.dayOfWeeks = [.monday, .friday]
        return EventRepeating(repeatingStartTime: 2200, repeatOption: option)
            |> \.repeatingEndOption .~ endOption
    }
    
    private func dummyFullSchedule(
        uuid: String = "schedule-uuid",
        tag: EventTagId? = .custom("tag-id"),
        showTurn: Bool = true,
        endOption: EventRepeating.RepeatEndOption = .until(3300)
    ) -> ScheduleEvent {
        return ScheduleEvent(uuid: uuid, name: "schedule name", time: .period(5500..<5600))
            |> \.eventTagId .~ tag
            |> \.repeating .~ pure(self.dummyWeeklyRepeating(endOption))
            |> \.showTurn .~ showTurn
            |> \.repeatingTimeToExcludes .~ ["exclude-1", "exclude-2", "exclude-3"]
            |> \.notificationOptions .~ [.atTime, .before(seconds: 600)]
    }
    
    func testRepository_whenSaveScheduleWithEveryColumn_loadRestoresSameValues() async throws {
        // given
        let origin = self.dummyFullSchedule()
        
        // when
        try await self.localStorage.saveScheduleEvent(origin)
        let restored = try await self.localStorage.loadScheduleEvent("schedule-uuid")
        
        // then
        XCTAssertEqual(restored.uuid, "schedule-uuid")
        XCTAssertEqual(restored.name, "schedule name")
        XCTAssertEqual(restored.eventTagId, .custom("tag-id"))
        XCTAssertEqual(restored.repeating, self.dummyWeeklyRepeating(.until(3300)))
        XCTAssertEqual(restored.repeating?.repeatingStartTime, 2200)
        XCTAssertEqual(restored.repeating?.repeatingEndOption, .until(3300))
        XCTAssertEqual(restored.showTurn, true)
        XCTAssertEqual(restored.repeatingTimeToExcludes, ["exclude-1", "exclude-2", "exclude-3"])
        XCTAssertEqual(restored.notificationOptions, [.atTime, .before(seconds: 600)])
        XCTAssertEqual(restored.time, .period(5500..<5600))
    }
    
    func testRepository_whenSaveScheduleRepeatsByCount_loadRestoresCountEndOption() async throws {
        // given
        let origin = self.dummyFullSchedule(endOption: .count(44))
        
        // when
        try await self.localStorage.saveScheduleEvent(origin)
        let restored = try await self.localStorage.loadScheduleEvent("schedule-uuid")
        
        // then
        XCTAssertEqual(restored.repeating?.repeatingEndOption, .count(44))
    }
    
    func testRepository_whenSaveScheduleRepeatsUntilTime_loadRestoresUntilEndOption() async throws {
        // given
        let origin = self.dummyFullSchedule(endOption: .until(3300))
        
        // when
        try await self.localStorage.saveScheduleEvent(origin)
        let restored = try await self.localStorage.loadScheduleEvent("schedule-uuid")
        
        // then
        XCTAssertEqual(restored.repeating?.repeatingEndOption, .until(3300))
    }
    
    func testRepository_whenSaveSchedulesWithEveryTagKind_loadRestoresSameTagId() async throws {
        // given
        let tags: [EventTagId] = [
            .holiday,
            .default,
            .custom("custom-tag"),
            .externalCalendar(serviceId: "google", id: "calendar-id")
        ]
        let origins = tags.enumerated().map { offset, tag in
            self.dummyFullSchedule(uuid: "schedule-\(offset)", tag: tag)
        }
        
        // when
        for origin in origins {
            try await self.localStorage.saveScheduleEvent(origin)
        }
        var restoredTags: [EventTagId?] = []
        for origin in origins {
            let restored = try await self.localStorage.loadScheduleEvent(origin.uuid)
            restoredTags.append(restored.eventTagId)
        }
        
        // then
        XCTAssertEqual(restoredTags, [
            .holiday,
            .default,
            .custom("custom-tag"),
            .externalCalendar(serviceId: "google", id: "calendar-id")
        ])
    }
    
    func testRepository_whenSaveSchedulesWithShowTurnOnAndOff_loadRestoresSameFlag() async throws {
        // given
        let showing = self.dummyFullSchedule(uuid: "show-on", showTurn: true)
        let hiding = self.dummyFullSchedule(uuid: "show-off", showTurn: false)
        
        // when
        try await self.localStorage.saveScheduleEvent(showing)
        try await self.localStorage.saveScheduleEvent(hiding)
        let restoredShowing = try await self.localStorage.loadScheduleEvent("show-on")
        let restoredHiding = try await self.localStorage.loadScheduleEvent("show-off")
        
        // then
        XCTAssertEqual(restoredShowing.showTurn, true)
        XCTAssertEqual(restoredHiding.showTurn, false)
    }
}


// MARK: - 변환이 컬럼을 다 채우는지 (DB 미사용)

extension ScheduleEventLocalRepositoryImpleTests {
    
    func testScheduleEntity_serialize_leavesNoColumnUnmapped() throws {
        // given
        let schedule = self.dummyFullSchedule()
        
        // when
        let values = try ScheduleEventTable.serialize(entity: .init(schedule))
        
        // then — 상호 배타인 종료 컬럼 둘은 아래 케이스가 맡는다
        let exclusiveColumns: Set<ScheduleEventTable.Columns> = [.repeatingEnd, .repeatingEndCount]
        let unmapped = zip(ScheduleEventTable.Columns.allCases, values)
            .filter { !exclusiveColumns.contains($0.0) && $0.1 == nil }
            .map { $0.0 }
        XCTAssertEqual(values.count, ScheduleEventTable.Columns.allCases.count)
        XCTAssertFalse(values.isEmpty)
        XCTAssertTrue(unmapped.isEmpty)
    }
    
    func testScheduleEntity_serializeRepeatingEndedByCount_leavesNoColumnUnmapped() throws {
        // given
        let untilSchedule = self.dummyFullSchedule(endOption: .until(3300))
        let countSchedule = self.dummyFullSchedule(endOption: .count(44))
        
        // when
        let untilValues = try ScheduleEventTable.serialize(entity: .init(untilSchedule))
        let countValues = try ScheduleEventTable.serialize(entity: .init(countSchedule))
        
        // then
        let mapped = zip(untilValues, countValues).map { $0 != nil || $1 != nil }
        XCTAssertEqual(mapped.count, ScheduleEventTable.Columns.allCases.count)
        XCTAssertFalse(mapped.isEmpty)
        XCTAssertTrue(mapped.allSatisfy { $0 })
    }
}
