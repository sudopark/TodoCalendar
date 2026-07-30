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
    private var stubGoogleCalendarRepository: StubGoogleCalendarRepository!
    private var stubAppleCalendarRepository: PrivateStubAppleCalendarRepository!

    override func setUpWithError() throws {
        self.stubTodoRepository = .init()
        self.stubScheduleRepository = .init()
        self.stubGoogleCalendarRepository = .init()
        self.stubAppleCalendarRepository = .init()
    }

    override func tearDownWithError() throws {
        self.stubTodoRepository = nil
        self.stubScheduleRepository = nil
        self.stubGoogleCalendarRepository = nil
        self.stubAppleCalendarRepository = nil
    }
    
    private func makeUsecase(
        withOffTags: [EventTagId] = [],
        hasForemost: Bool = true,
        isGoogleAccountIntegrated: Bool = false,
        isAppleCalendarIntegrated: Bool = false,
        shouldFailGoogleCalendar: Bool = false,
        shouldFailAppleCalendar: Bool = false,
        eventDetail: EventDetailData? = nil
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

        let externalCalendarRepository = StubExternalCalendarRepository(
            isGoogleAccountIntegrated: isGoogleAccountIntegrated,
            isAppleCalendarIntegrated: isAppleCalendarIntegrated
        )

        self.stubGoogleCalendarRepository.shouldFail = shouldFailGoogleCalendar
        self.stubAppleCalendarRepository.shouldFail = shouldFailAppleCalendar

        let detailRepository = StubEventDetailRepository()
        detailRepository.stubDetail = eventDetail

        return CalendarEventFetchUsecaseImple(
            todoRepository: self.stubTodoRepository,
            scheduleRepository: self.stubScheduleRepository,
            foremostEventRepository: foremostRepository,
            holidayFetchUsecase: holidayFetchUsecase,
            eventTagRepository: eventTagReopsitory,
            externalCalendarIntegrateRepository: externalCalendarRepository,
            googleCalendarRepository: self.stubGoogleCalendarRepository,
            appleCalendarRepository: self.stubAppleCalendarRepository,
            eventDetailRepository: detailRepository,
            cached: .init()
        )
    }

    private func makeUsecaseWithStubSchedule(
        _ schedule: ScheduleEvent
    ) -> CalendarEventFetchUsecaseImple {
        self.stubScheduleRepository.stubEvent = schedule
        return self.makeUsecase()
    }

    private func makeUsecaseWithoutStubSchedule() -> CalendarEventFetchUsecaseImple {
        self.stubScheduleRepository.stubEvent = nil
        return self.makeUsecase()
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
        XCTAssertEqual(events.appleCalendarTags.isEmpty, true)
    }

    func testUsecase_whenAppleCalendarIntegrated_provideAppleCalendarEvents() async throws {
        // given
        let usecase = self.makeUsecase(isAppleCalendarIntegrated: true)
        let range = self.dummyRange

        // when
        let events = try await usecase.fetchEvents(in: range, kst)

        // then
        let appleEvents = events.eventWithTimes.compactMap { $0 as? AppleCalendarEvent }
        XCTAssertEqual(appleEvents.count, 1)
        XCTAssertEqual(appleEvents.first?.name, "apple")
        XCTAssertEqual(events.appleCalendarTags.count, 2)
    }

    func testUsecase_whenAppleCalendarNotIntegrated_notProvideAppleCalendarEvents() async throws {
        // given
        let usecase = self.makeUsecase(isAppleCalendarIntegrated: false)
        let range = self.dummyRange

        // when
        let events = try await usecase.fetchEvents(in: range, kst)

        // then
        let appleEvents = events.eventWithTimes.compactMap { $0 as? AppleCalendarEvent }
        XCTAssertEqual(appleEvents.isEmpty, true)
        XCTAssertEqual(events.appleCalendarTags.isEmpty, true)
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
    
    // 애플캘린더 조회 실패 시에도 나머지 이벤트는 정상 반환
    func testUsecase_whenAppleCalendarFailed_stillReturnOtherEvents() async throws {
        // given
        let usecase = self.makeUsecase(
            isAppleCalendarIntegrated: true,
            shouldFailAppleCalendar: true
        )
        let range = self.dummyRange

        // when
        let events = try await usecase.fetchEvents(in: range, kst)

        // then
        XCTAssertEqual(events.currentTodos.count, 1)
        XCTAssertEqual(events.eventWithTimes.count, 3)
        XCTAssertEqual(events.appleCalendarTags.isEmpty, true)
    }

    // 구글캘린더 조회 실패 시에도 나머지 이벤트는 정상 반환
    func testUsecase_whenGoogleCalendarFailed_stillReturnOtherEvents() async throws {
        // given
        let usecase = self.makeUsecase(
            isGoogleAccountIntegrated: true,
            shouldFailGoogleCalendar: true
        )
        let range = self.dummyRange

        // when
        let events = try await usecase.fetchEvents(in: range, kst)

        // then
        XCTAssertEqual(events.currentTodos.count, 1)
        XCTAssertEqual(events.eventWithTimes.count, 3)
        XCTAssertEqual(events.googleCalendarTags.isEmpty, true)
        XCTAssertNil(events.googleCalendarColors)
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
    
    // 이벤트 반환시 비활성화된 이벤트는 제외하지 않음
    func testUsecase_whenFetchEvents_excludeOffEvents() async throws {
        // given
        let usecase = self.makeUsecase(withOffTags: [
            .custom("t2")
        ])
        let range = self.dummyRange
        
        // when
        let events = try await usecase.fetchEvents(in: range, kst, withoutOffTagIds: true)
        
        // then
        let eventNames = events.eventWithTimes.map { $0.name }
        XCTAssertEqual(eventNames, [
            "삼일절", "todo_with_lowerbound_time"
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
        let nextTodoWithExclude = TodoEvent(uuid: "next-but-exclude", name: "next-but-exclude")
            |> \.time .~ .at(refDate.timeIntervalSince1970 + 20)
            |> \.eventTagId .~ .custom("t1")
        let nextDayTodo = TodoEvent(uuid: "next-day", name: "next-day")
            |> \.time .~ .at(refDate.add(days: 1)!.timeIntervalSince1970)
        let schedule = ScheduleEvent(
            uuid: "second", name: "second-event", time: .at(refDate.timeIntervalSince1970 + 30)
        )
        
        if hasNext {
            self.stubTodoRepository.todoEventsMocking = [todo, nextTodoWithExclude, nextDayTodo]
        } else {
            self.stubTodoRepository.todoEventsMocking = [nextDayTodo]
        }
        
        if hasNext && hasNextNext {
            self.stubScheduleRepository.scheduleMocking = [schedule]
        } else {
            self.stubScheduleRepository.scheduleMocking = []
        }
        
        let detail = EventDetailData("first")
            |> \.place .~ .init("location")
        return self.makeUsecase(
            withOffTags: [.custom("t1")],
            eventDetail: detail
        )
    }
    
    private enum NextEventSource {
        case todo(TodoEvent, EventDetailData?)
        case schedule(ScheduleEvent, EventDetailData?)
        case google(GoogleCalendar.Event)
    }
    private func makeUsecase(with nextEvent: NextEventSource) -> CalendarEventFetchUsecaseImple {
        
        self.stubTodoRepository.todoEventsMocking = []
        self.stubScheduleRepository.scheduleMocking = []
        self.stubGoogleCalendarRepository.eventMocking = []
        var detail: EventDetailData?
        switch nextEvent {
        case .todo(let todo, let data):
            self.stubTodoRepository.todoEventsMocking = [todo]
            detail = data
        case .schedule(let schedule, let data):
            self.stubScheduleRepository.scheduleMocking = [schedule]
            detail = data
        case .google(let google):
            self.stubGoogleCalendarRepository.eventMocking = [google]
        }
        
        return self.makeUsecase(
            withOffTags: [.custom("t1")],
            isGoogleAccountIntegrated: true,
            eventDetail: detail
        )
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
        XCTAssertEqual(next?.nextEvent.locationText, "location")
        XCTAssertEqual(
            next?.andThenNextEventStartDate,
            refDate.addingTimeInterval(30)
        )
    }
    
    func testUsecase_whenFetchNextEvent_provideLocationTextByEventType() async throws {
        // given
        let refDate = Date(timeIntervalSince1970: 0)
        func parameterizeTest(_ source: NextEventSource, expectLocation: String?) async throws {
            // given
            let usecase = self.makeUsecase(with: source)
            
            // when
            let range = refDate.timeIntervalSince1970..<refDate.add(days: 1)!.timeIntervalSince1970
            let next = try await usecase.fetchNextEvent(refDate, within: range, self.kst)
            
            // then
            XCTAssertEqual(next != nil, true)
            XCTAssertEqual(next?.nextEvent.locationText, expectLocation)
        }
        // when + then
        var detail = EventDetailData("event") |> \.place .~ .init("todo place")
        let todo = TodoEvent(uuid: "event", name: "name") |> \.time .~ .at(refDate.timeIntervalSince1970 + 10)
        try await parameterizeTest(.todo(todo, nil), expectLocation: nil)
        try await parameterizeTest(.todo(todo, detail), expectLocation: "todo place")
        
        let schedule = ScheduleEvent(uuid: "event", name: "name", time: .at(refDate.timeIntervalSince1970 + 10))
        detail = detail |> \.place .~ .init("schedule place")
        try await parameterizeTest(.schedule(schedule, nil), expectLocation: nil)
        try await parameterizeTest(.schedule(schedule, detail), expectLocation: "schedule place")
        
        var google = GoogleCalendar.Event("e1", "", accountId: "stub@gmail.com", name: "", colorId: "", time: .at(refDate.timeIntervalSince1970 + 10))
        try await parameterizeTest(.google(google), expectLocation: nil)
        
        google = google |> \.location .~ "google location"
        try await parameterizeTest(.google(google), expectLocation: "google location")
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


// MARK: - D-day 대상 조회

extension CalendarEventFetchUsecaseImpleTests {

    private var repeatEveryDay: EventRepeating {
        return EventRepeating(
            repeatingStartTime: 0,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
    }

    func testUsecase_fetchDDayTarget_whenNotRepeating_returnsOriginTime() async throws {
        // given
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "워크숍", time: .at(1000))
        )

        // when
        let target = try await usecase.fetchDDayTargetEvent(
            .init(kind: .schedule, rawId: "s1")
        )

        // then
        XCTAssertEqual(target?.name, "워크숍")
        XCTAssertEqual(target?.time, .at(1000))
        XCTAssertEqual(target?.isRepeating, false)
    }

    func testUsecase_fetchDDayTarget_whenScheduleNotExists_returnsNil() async throws {
        // given
        let usecase = self.makeUsecaseWithoutStubSchedule()

        // when
        let target = try await usecase.fetchDDayTargetEvent(
            .init(kind: .schedule, rawId: "not-exists")
        )

        // then
        XCTAssertNil(target)
    }

    func testUsecase_fetchDDayTarget_whenRepeatingWithTurnKey_returnsThatTurnTime() async throws {
        // given: 매일 반복, origin = .at(0) → 4회차 = .at(3일)
        let fourthTurnTime = EventTime.at(3 * 24 * 3600)
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "운동", time: .at(0))
                |> \.repeating .~ self.repeatEveryDay
        )

        // when
        let target = try await usecase.fetchDDayTargetEvent(
            .init(kind: .schedule, rawId: "s1", turnKey: fourthTurnTime.customKey)
        )

        // then
        XCTAssertEqual(target?.time, fourthTurnTime)
        XCTAssertEqual(target?.isRepeating, true)
    }

    func testUsecase_fetchDDayTarget_whenTurnKeyIsExcluded_returnsNil() async throws {
        // given
        let excluded = EventTime.at(3 * 24 * 3600)
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "운동", time: .at(0))
                |> \.repeating .~ self.repeatEveryDay
                |> \.repeatingTimeToExcludes .~ [excluded.customKey]
        )

        // when
        let target = try await usecase.fetchDDayTargetEvent(
            .init(kind: .schedule, rawId: "s1", turnKey: excluded.customKey)
        )

        // then
        XCTAssertNil(target)
    }

    func testUsecase_fetchDDayTarget_whenTurnKeyIsPastRepeatEnd_returnsNil() async throws {
        // given: 2일 뒤까지만 반복 → 10일 뒤 회차는 존재하지 않는다
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "운동", time: .at(0))
                |> \.repeating .~ (
                    self.repeatEveryDay |> \.repeatingEndOption .~ .until(2 * 24 * 3600)
                )
        )

        // when
        let target = try await usecase.fetchDDayTargetEvent(
            .init(kind: .schedule, rawId: "s1", turnKey: EventTime.at(10 * 24 * 3600).customKey)
        )

        // then
        XCTAssertNil(target)
    }

    func testUsecase_fetchDDayTarget_whenNoTurnLandsOnTurnKey_returnsNil() async throws {
        // given: 매일 반복이라 어떤 회차도 3일+100초에 오지 않는다 (원본 시각이 밀린 상황)
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "운동", time: .at(0))
                |> \.repeating .~ self.repeatEveryDay
        )

        // when
        let target = try await usecase.fetchDDayTargetEvent(
            .init(kind: .schedule, rawId: "s1", turnKey: EventTime.at(3 * 24 * 3600 + 100).customKey)
        )

        // then
        XCTAssertNil(target)
    }

    func testUsecase_fetchDDayTarget_whenTurnKeyIsBeforeOrigin_returnsNil() async throws {
        // given: origin이 목표 시각보다 뒤 — 전진 열거로는 닿을 수 없다
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "운동", time: .at(10 * 24 * 3600))
                |> \.repeating .~ self.repeatEveryDay
        )

        // when
        let target = try await usecase.fetchDDayTargetEvent(
            .init(kind: .schedule, rawId: "s1", turnKey: EventTime.at(0).customKey)
        )

        // then
        XCTAssertNil(target)
    }

    func testUsecase_fetchScheduleRepeatingTurns_listsTurnsInRange() async throws {
        // given: 매일 반복, origin = .at(0)
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "운동", time: .at(0))
                |> \.repeating .~ self.repeatEveryDay
        )

        // when
        let turns = try await usecase.fetchScheduleRepeatingTurns(
            "s1", in: 0..<(5 * 24 * 3600), limit: 50
        )

        // then: origin(1회차) + 2~5회차
        XCTAssertEqual(turns.count, 5)
        XCTAssertEqual(turns.first?.turn, 1)
        XCTAssertEqual(turns.first?.time, .at(0))
    }

    func testUsecase_fetchScheduleRepeatingTurns_respectsLimit() async throws {
        // given
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "운동", time: .at(0))
                |> \.repeating .~ self.repeatEveryDay
        )

        // when
        let turns = try await usecase.fetchScheduleRepeatingTurns(
            "s1", in: 0..<(100 * 24 * 3600), limit: 3
        )

        // then
        XCTAssertEqual(turns.count, 3)
    }

    func testUsecase_fetchScheduleRepeatingTurns_whenNotRepeating_returnsEmpty() async throws {
        // given
        let usecase = self.makeUsecaseWithStubSchedule(
            ScheduleEvent(uuid: "s1", name: "워크숍", time: .at(0))
        )

        // when
        let turns = try await usecase.fetchScheduleRepeatingTurns(
            "s1", in: 0..<(5 * 24 * 3600), limit: 50
        )

        // then
        XCTAssertEqual(turns.isEmpty, true)
    }
}


// MARK: - D-day 대상 키

extension CalendarEventFetchUsecaseImpleTests {

    func testHolidayTargetKey_roundTrip() {
        // given
        let key = HolidayTargetKey(
            countryCode: "KR", dateString: "2027-03-01", name: "삼일절"
        )

        // when
        let restored = HolidayTargetKey(rawId: key.rawId)

        // then
        XCTAssertEqual(restored?.countryCode, "KR")
        XCTAssertEqual(restored?.dateString, "2027-03-01")
        XCTAssertEqual(restored?.name, "삼일절")
        XCTAssertEqual(restored?.year, 2027)
    }

    func testHolidayTargetKey_whenNameContainsSeparator_keepsWholeName() {
        // given
        let key = HolidayTargetKey(
            countryCode: "KR", dateString: "2027-03-01", name: "어떤::공휴일"
        )

        // when
        let restored = HolidayTargetKey(rawId: key.rawId)

        // then
        XCTAssertEqual(restored?.name, "어떤::공휴일")
    }

    func testHolidayTargetKey_whenSegmentsInsufficient_returnsNil() {
        // given + when
        let restored = HolidayTargetKey(rawId: "KR::2027-03-01")

        // then
        XCTAssertNil(restored)
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
        let holiday = Holiday(uuid: "id", dateString: "2024-03-01", name: "삼일절")
        return [holiday]
    }

    var stubCountryCode: String? = "KR"
    func currentCountryCode() async -> String? {
        return self.stubCountryCode
    }
}
