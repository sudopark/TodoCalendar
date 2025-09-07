//
//  CalendarEventFetchUsecaseImpleTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 6/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes
import UnitTestHelpKit
import TestDoubles


class CalendarEventFetchUsecaseImpleTests: BaseTestCase {
    
    private var stubTodoRepository: PrivateStubTodoRepository!
    private var stubScheduleRepository: PrivateStubScheduleRepository!
    
    override func setUpWithError() throws {
        self.stubTodoRepository = .init()
        self.stubScheduleRepository = .init()
    }
    
    override func tearDownWithError() throws {
        self.stubTodoRepository = nil
        self.stubScheduleRepository = nil
    }
    
    private func makeUsecase(
        withOffTags: [EventTagId] = [],
        hasForemost: Bool = true,
        isGoogleAccountIntegrated: Bool = false
    ) -> CalendarEventFetchUsecaseImple {
        
        let holidayFetchUsecase = StubHolidaysFetchUsecase()
        let eventTagReopsitory = StubEventTagRepository()
        eventTagReopsitory.allTagsStubbing = [
            .init(uuid: "t1", name: "tag-1", colorHex: "some"),
            .init(uuid: "t2", name: "tag-2", colorHex: "some"),
            .init(uuid: "t3", name: "tag-3", colorHex: "some")
        ]
        withOffTags.forEach {
            _ = eventTagReopsitory.toggleTagIsOn($0)
        }
        let foremostRepository = PrivateStubForemostEventRepository()
        foremostRepository.stubHasForemost = hasForemost
        
        let externalCalendarRepository = StubExternalCalendarRepository(isGoogleAccountIntegrated: isGoogleAccountIntegrated)
        let googleCalendarRepository = StubGoogleCalendarRepository()
        
        return CalendarEventFetchUsecaseImple(
            todoRepository: self.stubTodoRepository,
            scheduleRepository: self.stubScheduleRepository,
            foremostEventRepository: foremostRepository,
            holidayFetchUsecase: holidayFetchUsecase,
            eventTagRepository: eventTagReopsitory,
            externalCalendarIntegrateRepository: externalCalendarRepository,
            googleCalendarRepository: googleCalendarRepository,
            cached: .init()
        )
    }
}


extension CalendarEventFetchUsecaseImpleTests {
    
    private var kst: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    private var dummyRange: Range<TimeInterval> {
        let calendar = Calendar(identifier: .gregorian)
            |> \.timeZone .~ self.kst
        let m1 = calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 3; $0.day = 1
        }!
        let a1 = calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 4; $0.day = 1
        }!
        return calendar.startOfDay(for: m1).timeIntervalSince1970..<a1.timeIntervalSince1970
    }
    
    // 해당시간에 해당하는 이벤트 정보 반환
    func testUsecase_fetchEvents() async throws {
        // given
        let usecase = self.makeUsecase()
        let range = self.dummyRange
        
        // when
        let events = try await usecase.fetchEvents(in: range, kst)
        
        // then
        XCTAssertEqual(events.currentTodos.count, 1)
        XCTAssertEqual(events.currentTodos.first?.name, "current todo")
        
        XCTAssertEqual(events.eventWithTimes.count, 3)
        let todoWithTime = events.eventWithTimes.compactMap {
            $0 as? TodoCalendarEvent
        }.first
        XCTAssertEqual(todoWithTime?.name, "todo_with_lowerbound_time")
        
        let schedule = events.eventWithTimes.compactMap {
            $0 as? ScheduleCalendarEvent
        }.first
        XCTAssertEqual(schedule?.name, "scheudle_with_upperbound_time")
        
        let holiday = events.eventWithTimes.compactMap {
            $0 as? HolidayCalendarEvent
        }.first
        XCTAssertEqual(holiday?.name, "삼일절")
        
        XCTAssertEqual(events.googleCalendarTags.isEmpty, true)
        XCTAssertEqual(events.googleCalendarColors, nil)
    }
    
    func testUsecase_whenGoogleCalendarIntegrated_provideGoogleCalendarEvents() async throws {
        // given
        let usecase = self.makeUsecase(isGoogleAccountIntegrated: true)
        let range = self.dummyRange
        
        // when
        let events = try await usecase.fetchEvents(in: range, kst)
        
        // then
        XCTAssertEqual(events.currentTodos.count, 1)
        XCTAssertEqual(events.currentTodos.first?.name, "current todo")
        
        XCTAssertEqual(events.eventWithTimes.count, 5)
        let todoWithTime = events.eventWithTimes.compactMap {
            $0 as? TodoCalendarEvent
        }.first
        XCTAssertEqual(todoWithTime?.name, "todo_with_lowerbound_time")
        
        let schedule = events.eventWithTimes.compactMap {
            $0 as? ScheduleCalendarEvent
        }.first
        XCTAssertEqual(schedule?.name, "scheudle_with_upperbound_time")
        
        let holiday = events.eventWithTimes.compactMap {
            $0 as? HolidayCalendarEvent
        }.first
        XCTAssertEqual(holiday?.name, "삼일절")
        
        let google = events.eventWithTimes.compactMap {
            $0 as? GoogleCalendarEvent
        }.first
        XCTAssertEqual(google?.name, "google")
        XCTAssertEqual(events.googleCalendarTags.count, 2)
        XCTAssertEqual(events.googleCalendarColors?.events.count, 1)
        XCTAssertEqual(events.googleCalendarColors?.calendars.count, 1)
    }
    
    // 해당시간에 해당하는 이벤트 정보 반환시에 시간순 정렬
    func testUsecase_whenFetchEvents_sortByTime() async throws {
        // given
        let usecase = self.makeUsecase()
        let range = self.dummyRange
        
        // when
        let events = try await usecase.fetchEvents(in: range, kst)
        
        // then
        let eventNames = events.eventWithTimes.map { $0.name }
        XCTAssertEqual(eventNames, [
            "삼일절", "todo_with_lowerbound_time", "scheudle_with_upperbound_time"
        ])
    }
    
    // 이벤트 반환시 비활성화된 이벤트는 제외하지 않음
    func testUsecase_whenFetchEvents_notExcludeOffEvents() async throws {
        // given
        let usecase = self.makeUsecase(withOffTags: [
            .custom("t2")
        ])
        let range = self.dummyRange
        
        // when
        let events = try await usecase.fetchEvents(in: range, kst)
        
        // then
        let eventNames = events.eventWithTimes.map { $0.name }
        XCTAssertEqual(eventNames, [
            "삼일절", "todo_with_lowerbound_time", "scheudle_with_upperbound_time"
        ])
    }
    
    // 이벤트 반환시에 커스텀 이벤트 태그맵 정보 같이 반환
    func testUsecase_fetchEvents_withAllCustomTags() async throws {
        // given
        let usecase = self.makeUsecase()
        let range = self.dummyRange
        
        // when
        let events = try await usecase.fetchEvents(in: range, kst)
        
        // then
        let keys = events.customTagMap.keys.sorted()
        XCTAssertEqual(keys, [
            "t1", "t2", "t3"
        ])
    }
}

extension CalendarEventFetchUsecaseImpleTests {
    
    func testUsecase_fetchForemostEvent() async throws {
        // given
        func parameterizeTest(expectHasEvent: Bool) async throws {
            // given
            let usecase = self.makeUsecase(hasForemost: expectHasEvent)
            
            // when
            let event = try await usecase.fetchForemostEvent()
            
            // then
            XCTAssertEqual(event.foremostEvent != nil, expectHasEvent)
        }
        // when + then
        try await parameterizeTest(expectHasEvent: false)
        try await parameterizeTest(expectHasEvent: true)
    }
}

extension CalendarEventFetchUsecaseImpleTests {
    
    private func makeUsecaseWithStubNextEvents(
        _ refDate: Date,
        hasNext: Bool = true,
        hasNextNext: Bool = true
    ) -> CalendarEventFetchUsecaseImple {
        
        let todo = TodoEvent(uuid: "first", name: "first-event")
            |> \.time .~ .at(refDate.timeIntervalSince1970 + 10)
        let nextDayTodo = TodoEvent(uuid: "next-day", name: "next-day")
            |> \.time .~ .at(refDate.add(days: 1)!.timeIntervalSince1970)
        let schedule = ScheduleEvent(
            uuid: "second", name: "second-event", time: .at(refDate.timeIntervalSince1970 + 30)
        )
        
        if hasNext {
            self.stubTodoRepository.todoEventsMocking = [todo, nextDayTodo]
        } else {
            self.stubTodoRepository.todoEventsMocking = [nextDayTodo]
        }
        
        if hasNext && hasNextNext {
            self.stubScheduleRepository.scheduleMocking = [schedule]
        } else {
            self.stubScheduleRepository.scheduleMocking = []
        }
        return self.makeUsecase()
    }
    
    func testUsecase_fetchNextEvent() async throws {
        // given
        let refDate = Date(timeIntervalSince1970: 0)
        let usecase = self.makeUsecaseWithStubNextEvents(refDate)
        
        // when
        let range = refDate.timeIntervalSince1970..<refDate.add(days: 1)!.timeIntervalSince1970
        let next = try await usecase.fetchNextEvent(refDate, within: range, self.kst)
        
        // then
        XCTAssertEqual(next?.nextEvent.name, "first-event")
        XCTAssertEqual(
            next?.andThenNextEventStartDate,
            refDate.addingTimeInterval(30)
        )
    }
    
    func testUsecase_fetchNextEvent_withoutSecondNextEvent() async throws {
        // given
        let refDate = Date(timeIntervalSince1970: 0)
        let usecase = self.makeUsecaseWithStubNextEvents(
            refDate, hasNextNext: false
        )
        
        // when
        let range = refDate.timeIntervalSince1970..<refDate.add(days: 1)!.timeIntervalSince1970
        let next = try await usecase.fetchNextEvent(refDate, within: range, self.kst)
        
        // then
        XCTAssertEqual(next?.nextEvent.name, "first-event")
        XCTAssertEqual(
            next?.andThenNextEventStartDate,
            nil
        )
    }
    
    func testUsecase_fetchNextEvent_withoutNextEvent() async throws {
        // given
        let refDate = Date(timeIntervalSince1970: 0)
        let usecase = self.makeUsecaseWithStubNextEvents(
            refDate, hasNext: false
        )
        
        // when
        let range = refDate.timeIntervalSince1970..<refDate.add(days: 1)!.timeIntervalSince1970
        let next = try await usecase.fetchNextEvent(refDate, within: range, self.kst)
        
        // then
        XCTAssertNil(next)
    }
    
    func testUsecase_fetNextEvents() async throws {
        // given
        let refDate = Date(timeIntervalSince1970: 0)
        let usecase = self.makeUsecaseWithStubNextEvents(refDate, hasNext: true, hasNextNext: true)
        
        // when
        let range = refDate.timeIntervalSince1970..<refDate.add(days: 1)!.timeIntervalSince1970
        let nexts = try await usecase.fetchNextEvents(refDate, withIn: range, self.kst)
        
        // then
        XCTAssertEqual(nexts.nextEvents.count, 2)
    }
    
    func testUsecase_whenFetchNextEvents_excludePastEventThanNow() async throws {
        // given
        let todayStart = Date(timeIntervalSince1970: 0)
        let current = Date(timeIntervalSince1970: 20)
        let usecase = self.makeUsecaseWithStubNextEvents(todayStart, hasNext: true, hasNextNext: true)
        
        // when
        let range = todayStart.timeIntervalSince1970..<todayStart.add(days: 1)!.timeIntervalSince1970
        let nexts = try await usecase.fetchNextEvents(current, withIn: range, self.kst
        )
        
        // then
        XCTAssertEqual(nexts.nextEvents.count, 1)
    }
}

private final class PrivateStubTodoRepository: StubTodoEventRepository, @unchecked Sendable {
    
    override func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], any Error> {
        
        let todo = TodoEvent(uuid: "current", name: "current todo")
            |> \.eventTagId .~ .custom("t1")
        return Just([todo]).mapAsAnyError().eraseToAnyPublisher()
    }
    
    var todoEventsMocking: [TodoEvent]?
    
    override func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error> {
        
        if let mocking = self.todoEventsMocking {
            return Just(mocking).mapNever().eraseToAnyPublisher()
        }
        
        let todo = TodoEvent(uuid: "todo", name: "todo_with_lowerbound_time")
            |> \.time .~ .at(range.lowerBound + 1)
        return Just([todo]).mapAsAnyError().eraseToAnyPublisher()
    }
}
private final class PrivateStubScheduleRepository: StubScheduleEventRepository, @unchecked Sendable {
    
    var scheduleMocking: [ScheduleEvent]?
 
    override func loadScheduleEvents(in range: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], any Error> {
        
        if let mocking = self.scheduleMocking {
            return Just(mocking).mapNever().eraseToAnyPublisher()
        }
        
        let event = ScheduleEvent(
            uuid: "schedule", name: "scheudle_with_upperbound_time",
            time: .at(range.upperBound-1)
        )
        |> \.eventTagId .~ .custom("t2")
        return Just([event]).mapAsAnyError().eraseToAnyPublisher()
    }
}


private final class PrivateStubForemostEventRepository: StubForemostEventRepository, @unchecked Sendable {
    
    var stubHasForemost: Bool = true
    override func foremostEvent() -> AnyPublisher<(any ForemostMarkableEvent)?, any Error> {
        guard self.stubHasForemost
        else {
            return Just(nil).mapAsAnyError().eraseToAnyPublisher()
        }
        
        let event = TodoEvent(uuid: "dummy_foremost", name: "some")
        return Just(event).mapAsAnyError().eraseToAnyPublisher()
    }
}

private final class StubHolidaysFetchUsecase: HolidaysFetchUsecase {
    
    func reset() async throws { }
    
    func holidaysGivenYears(
        _ range: Range<TimeInterval>, timeZone: TimeZone
    ) async throws -> [Holiday] {
        let holiday = Holiday(dateString: "2024-03-01", name: "삼일절")
        return [holiday]
    }
}
