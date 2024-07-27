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
    
    private func makeUsecase(
        withOffTags: [AllEventTagId] = [],
        hasForemost: Bool = true
    ) -> CalendarEventFetchUsecaseImple {
        
        let todoRepository = PrivateStubTodoRepository()
        let scheduleRepository = PrivateStubScheduleRepository()
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
        
        return CalendarEventFetchUsecaseImple(
            todoRepository: todoRepository,
            scheduleRepository: scheduleRepository,
            foremostEventRepository: foremostRepository,
            holidayFetchUsecase: holidayFetchUsecase,
            eventTagRepository: eventTagReopsitory,
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

private final class PrivateStubTodoRepository: StubTodoEventRepository {
    
    override func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], any Error> {
        
        let todo = TodoEvent(uuid: "current", name: "current todo")
            |> \.eventTagId .~ .custom("t1")
        return Just([todo]).mapAsAnyError().eraseToAnyPublisher()
    }
    
    override func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error> {
        let todo = TodoEvent(uuid: "todo", name: "todo_with_lowerbound_time")
            |> \.time .~ .at(range.lowerBound + 1)
        return Just([todo]).mapAsAnyError().eraseToAnyPublisher()
    }
}
private final class PrivateStubScheduleRepository: StubScheduleEventRepository {
 
    override func loadScheduleEvents(in range: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], any Error> {
        let event = ScheduleEvent(
            uuid: "schedule", name: "scheudle_with_upperbound_time",
            time: .at(range.upperBound-1)
        )
        |> \.eventTagId .~ .custom("t2")
        return Just([event]).mapAsAnyError().eraseToAnyPublisher()
    }
}


private final class PrivateStubForemostEventRepository: StubForemostEventRepository {
    
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
        let holiday = Holiday(dateString: "2024-03-01", localName: "삼일절", name: "삼일절")
        return [holiday]
    }
}
