//
//  EventListWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 6/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes
import UnitTestHelpKit
import TestDoubles


class EventListWidgetViewModelProviderTests: BaseTestCase {
        
    private func makeProvider(
        withCurrentTodo: Bool = true,
        withStartDateEvent: Bool = true,
        withoutAnyEventsIncludeHoliday: Bool = false
    ) -> EventListWidgetViewModelProvider {
        
        let fetchUsecase = StubCalendarEventsFetchUescase()
        fetchUsecase.hasCurrentTodo = withCurrentTodo
        fetchUsecase.hasEventAtStartDate = withStartDateEvent
        fetchUsecase.withoutAnyEvents = withoutAnyEventsIncludeHoliday
        fetchUsecase.hasHoliday = !withoutAnyEventsIncludeHoliday
        
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        
        return .init(
            eventsFetchUsecase: fetchUsecase, appSettingRepository: appSettingRepository, calendarSettingRepository: calendarSettingRepository
        )
    }
}


extension EventListWidgetViewModelProviderTests {
    
    private var kst: TimeZone { TimeZone(abbreviation: "KST")! }
    
    private var refDate: Date {
        let calenadr = Calendar(identifier: .gregorian) |> \.timeZone .~ self.kst
        return calenadr.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 3; $0.day = 1
        }!
    }
    
    private var endDate: Date {
        return self.refDate.add(days: 90)!
    }
    
    func testProvide_provideViewModel() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 100)
        
        // then
        XCTAssertEqual(viewModel.lists.count, 3)
        let currentModel = viewModel.lists[safe: 0]
        XCTAssertEqual(currentModel?.sectionTitle, "Current todo".localized())
        XCTAssertEqual(currentModel?.events.map { $0.name }, [
            "current"
        ])
        
        let firstDateModel = viewModel.lists[safe: 1]
        XCTAssertEqual(
            firstDateModel?.sectionTitle,
            self.refDate.text("EEE, MMM d".localized(), timeZone: kst)
        )
        XCTAssertEqual(firstDateModel?.events.map { $0.name }, [
            "todo_at_start"
        ])
        
        let lastDateModel = viewModel.lists[safe: 2]
        XCTAssertEqual(
            lastDateModel?.sectionTitle,
            self.endDate.text("EEE, MMM d".localized(), timeZone: kst)
        )
        XCTAssertEqual(lastDateModel?.events.map { $0.name }, [
            "holiday",
            "scheudle_at_last",
            "todo_at_last"
        ])
    }
    
    func testProvider_whenCurrentTodoNotExists_doNotProvideCurrentTodoDayModel() async throws {
        // given
        let provider = self.makeProvider(withCurrentTodo: false)
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 100)
        
        // then
        XCTAssertEqual(viewModel.lists.count, 2)
        XCTAssertNil(
            viewModel.lists.first(where: { $0.isCurrentTodos  })
        )
    }
    
    func testProvider_whenStartDateEventNotExists_providerWithEmptyDayModel() async throws {
        // given
        let provider = self.makeProvider(withStartDateEvent: false)
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 100)
        
        // then
        let currentModel = viewModel.lists[safe: 0]
        XCTAssertEqual(currentModel?.sectionTitle, "Current todo".localized())
        XCTAssertEqual(currentModel?.events.map { $0.name }, [
            "current"
        ])
        
        let firstDateModel = viewModel.lists[safe: 1]
        XCTAssertEqual(
            firstDateModel?.sectionTitle,
            self.refDate.text("EEE, MMM d".localized(), timeZone: kst)
        )
        XCTAssertEqual(firstDateModel?.events.map { $0.name }, [])
        
        let lastDateModel = viewModel.lists[safe: 2]
        XCTAssertEqual(
            lastDateModel?.sectionTitle,
            self.endDate.text("EEE, MMM d".localized(), timeZone: kst)
        )
        XCTAssertEqual(lastDateModel?.events.map { $0.name }, [
            "holiday",
            "scheudle_at_last",
            "todo_at_last"
        ])
    }
    
    func testProvider_provideWithEventTagColor() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 100)
        
        // then
        let eventModels = viewModel.lists.flatMap { $0.events }
        let colors = eventModels.map { $0.tagColor }
        XCTAssertEqual(colors, [
            .default,   // current todo
            .default,   // start date todo,
            .holiday,   // last date
            .custom(hex: "t1"),  // last date schedule event
            .custom(hex: "t2")  // last date todo event
        ])
    }
    
    func testProvider_whenEvenThoughEventsIsEmpty_provideFirstDateEvent() async throws {
        // given
        let provider = self.makeProvider(withoutAnyEventsIncludeHoliday: true)
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 100)
        
        // then
        XCTAssertEqual(viewModel.lists.count, 1)
        XCTAssertEqual(
            viewModel.lists.first?.sectionTitle, 
            self.refDate.text("EEE, MMM d".localized(), timeZone: kst)
        )
        XCTAssertEqual(viewModel.lists.first?.events.count, 0)
    }
}

extension EventListWidgetViewModelProviderTests {
    
    private final class PrivateStubEventFetchUsecase: StubCalendarEventsFetchUescase {
        let currentTodos: [TodoCalendarEvent]
        let eventWithTimes: [any CalendarEvent]
        
        init(currentTodos: [TodoCalendarEvent], eventWithTimes: [any CalendarEvent]) {
            self.currentTodos = currentTodos
            self.eventWithTimes = eventWithTimes
        }
        
        override func fetchEvents(in range: Range<TimeInterval>, _ timeZone: TimeZone) async throws -> CalendarEvents {
            return .init(currentTodos: self.currentTodos, eventWithTimes: self.eventWithTimes, customTagMap: [:])
        }
    }
    
    private func makeProviderWthStub(
        currentTodosCount: Int = 0,
        todayEventCount: Int = 0,
        otherDayEventCount: Int = 0
    ) -> EventListWidgetViewModelProvider {
        
        let first = self.refDate.timeIntervalSince1970
        let second = self.refDate.add(days: 1)!.timeIntervalSince1970
        let currents = (0..<currentTodosCount).map {
            let todo = TodoEvent(uuid: "current:\($0)", name: "dummy")
            return TodoCalendarEvent(todo, in: kst)
        }
        let todays = (0..<todayEventCount).map {
            let todo = TodoEvent(uuid: "today:\($0)", name: "dummy") |> \.time .~ .at(first + TimeInterval($0+1))
            return TodoCalendarEvent(todo, in: kst)
        }
        let otherDays = (0..<otherDayEventCount).map {
            let todo = TodoEvent(uuid: "other:\($0)", name: "dummy") |> \.time .~ .at(second + TimeInterval($0+1))
            return TodoCalendarEvent(todo, in: kst)
        }
        
        let usecase = PrivateStubEventFetchUsecase(
            currentTodos: currents,
            eventWithTimes: todays + otherDays
        )
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        
        return EventListWidgetViewModelProvider(
            eventsFetchUsecase: usecase,
            appSettingRepository: appSettingRepository,
            calendarSettingRepository: calendarSettingRepository
        )
    }
    
    // 첫날에 해당하는 이벤트는 없는경우 빈 모델로 반환
    func testProvider_whenFirstDayIsEmpty_provideEmptyFirstDateModel() async throws {
        // given
        let provider = self.makeProviderWthStub(
            todayEventCount: 0,
            otherDayEventCount: 0
        )
        
        // when
        let model = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 3)
        
        // then
        XCTAssertEqual(model.lists.count, 1)
        let todaySection = model.lists.first(where: { $0.sectionTitle == "Fri, Mar 1" })
        XCTAssertNotNil(todaySection)
        XCTAssertEqual(todaySection?.events.count, 0)
    }

    // current todo는 있지만 첫날에 해당하는 이벤트가 없는 경우에도 첫날은 빈 모델로 반환
    func testProvider_whenCurrentTodoExistsAndFirstDayIsEmpty_provideEmptyFirstDateModel() async throws {
        // given
        let provider = self.makeProviderWthStub(
            currentTodosCount: 1,
            todayEventCount: 0,
            otherDayEventCount: 0
        )
        
        // when
        let model = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 3)
        
        // then
        XCTAssertEqual(model.lists.count, 2)
        let currentSection = model.lists.first(where: { $0.isCurrentTodos == true })
        XCTAssertEqual(currentSection?.events.count, 1)
        let todaySection = model.lists.first(where: { $0.sectionTitle == "Fri, Mar 1" })
        XCTAssertNotNil(todaySection)
        XCTAssertEqual(todaySection?.events.count, 0)
    }

    // current todo가 max를 충족한경우 첫날은 미제공
    func testProvider_whenCurrentTodoGTEMaxCount_notProvideFirstDate() async throws {
        // given
        let provider = self.makeProviderWthStub(
            currentTodosCount: 3,
            todayEventCount: 0,
            otherDayEventCount: 0
        )
        
        // when
        let model = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 3)
        
        // then
        XCTAssertEqual(model.lists.count, 1)
        let currentSection = model.lists.first(where: { $0.isCurrentTodos == true })
        XCTAssertEqual(currentSection?.events.count, 3)
        let todaySection = model.lists.first(where: { $0.sectionTitle == "Fri, Mar 1" })
        XCTAssertNil(todaySection)
    }

    // 전체 이벤트수 제한 걸린경우 필터링
    func testProvider_limitTotalEventCount() async throws {
        // given
        func parameterizeTest(current: Int, today: Int, other: Int) async throws {
            // given
            let provider = self.makeProviderWthStub(
                currentTodosCount: current,
                todayEventCount: today,
                otherDayEventCount: other
            )
            
            // when
            let model = try await provider.getEventListViewModel(for: self.refDate, maxItemCount: 3)
            
            // then
            let totalCount = model.lists.reduce(0) { acc, section in
                return section.events.isEmpty ? acc + 1 : acc + section.events.count
            }
            XCTAssertEqual(totalCount, 3)
        }
        
        // when + then
        try await parameterizeTest(current: 3, today: 1, other: 0)
        try await parameterizeTest(current: 3, today: 1, other: 1)
        try await parameterizeTest(current: 2, today: 0, other: 1)
        try await parameterizeTest(current: 0, today: 3, other: 1)
        try await parameterizeTest(current: 0, today: 4, other: 1)
        try await parameterizeTest(current: 0, today: 0, other: 2)
        try await parameterizeTest(current: 0, today: 0, other: 3)
        try await parameterizeTest(current: 0, today: 0, other: 4)
        
    }
}


extension EventListWidgetViewModelProviderTests {
    
    private final class StubSingleEventFetchUsecase: StubCalendarEventsFetchUescase {
        let event: any CalendarEvent
        init(event: any CalendarEvent) {
            self.event = event
        }
        
        override func fetchEvents(in range: Range<TimeInterval>, _ timeZone: TimeZone) async throws -> CalendarEvents {
            return .init(currentTodos: [], eventWithTimes: [self.event], customTagMap: [:])
        }
    }
    
    func makeProviderWithSingleEvent(_ event: CalendarEvent) -> EventListWidgetViewModelProvider {
        
        let usecase = StubSingleEventFetchUsecase(event: event)
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        
        return EventListWidgetViewModelProvider(
            eventsFetchUsecase: usecase,
            appSettingRepository: appSettingRepository,
            calendarSettingRepository: calendarSettingRepository
        )
    }
    
    var dummyPDTAlldayTodo: TodoCalendarEvent {
        let pdt = TimeZone(abbreviation: "PDT")!
        let calednar = Calendar(identifier: .gregorian)
            |> \.timeZone .~ pdt
        let refDateAsPdt = calednar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 3; $0.day = 1
        }
        let allDayRange = calednar.dayRange(refDateAsPdt!)!
        let todo = TodoEvent(uuid: "allday_todo", name: "allday todo")
            |> \.time .~ .allDay(
                allDayRange,
                secondsFromGMT: TimeInterval(pdt.secondsFromGMT(
                    for: Date(timeIntervalSince1970: allDayRange.lowerBound)
                ))
            )
        return TodoCalendarEvent(todo, in: self.kst)
    }
    
    func testProvider_whenEventIsAllDay_onlyShowThatDay() async throws {
        // given
        let usecase = self.makeProviderWithSingleEvent(self.dummyPDTAlldayTodo)
        
        // when
        let viewModel = try await usecase.getEventListViewModel(for: self.refDate, maxItemCount: 100)
        
        // then
        let allEvents = viewModel.lists.flatMap { $0.events }
        let refDateEvent = allEvents.first as? TodoEventCellViewModel
        XCTAssertEqual(refDateEvent?.name, "allday todo")
        XCTAssertEqual(allEvents.count, 1)
    }
}


extension EventListWidgetViewModelProviderTests {
    
    private final class UnSortedStubEventsFetchUsecase: CalendarEventFetchUsecase {
        private let refDate: Date
        init(refDate: Date) { self.refDate = refDate }
        
        func fetchEvents(
            in range: Range<TimeInterval>, _ timeZone: TimeZone
        ) async throws -> CalendarEvents {
            
            let refTime = self.refDate.timeIntervalSince1970
            let kst = TimeZone(abbreviation: "KST")!
            let currents = [30, 90, 1].map { int -> TodoEvent in
                return TodoEvent(uuid: "current-\(int)", name: "current")
                |> \.creatTimeStamp .~ (refTime + TimeInterval(int))
            }
            .map { TodoCalendarEvent($0, in: kst) }
            let events = [20, 100, 10].map { int -> TodoEvent in
                return TodoEvent(uuid: "todo-\(int)", name: "some")
                |> \.time .~ .at(TimeInterval(int) + refTime)
            }
            .map { TodoCalendarEvent($0, in: kst) }
            
            return .init(
                currentTodos: currents, eventWithTimes: events, customTagMap: [:]
            )
        }
        
        func fetchForemostEvent() async throws -> ForemostEventAndTag {
            return .init(foremostEvent: nil, tag: nil)
        }
    }
    
    private func makeProviderWithStubUnsortedEvents() -> EventListWidgetViewModelProvider {
        
        let fetchUsecase = UnSortedStubEventsFetchUsecase(refDate: self.refDate)
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        return .init(
            eventsFetchUsecase: fetchUsecase, 
            appSettingRepository: appSettingRepository,
            calendarSettingRepository: calendarSettingRepository
        )
    }
    
    func testProvider_sortEvents() async throws {
        // given
        let provider = self.makeProviderWithStubUnsortedEvents()
        
        // when
        let viewModel = try await provider.getEventListViewModel(
            for: self.refDate, maxItemCount: 100
        )
        
        // then
        XCTAssertEqual(viewModel.lists.count, 2)
        let currents = viewModel.lists.first(where: { $0.isCurrentTodos })
        let section0 = viewModel.lists.first(where: { !$0.isCurrentTodos })
        XCTAssertEqual(currents?.events.map { $0.eventIdentifier}, [
            "current-1", "current-30", "current-90",
        ])
        XCTAssertEqual(section0?.events.map { $0.eventIdentifier }, [
            "todo-10", "todo-20", "todo-100"
        ])
    }
}
