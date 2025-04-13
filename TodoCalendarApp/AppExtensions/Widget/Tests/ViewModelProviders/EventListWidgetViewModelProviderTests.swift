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
        selectTagId: EventTagId = .default,
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
            targetEventTagId: selectTagId,
            eventsFetchUsecase: fetchUsecase,
            appSettingRepository: appSettingRepository,
            calendarSettingRepository: calendarSettingRepository
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
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        XCTAssertEqual(viewModel.pages.count, 1)
        let firstPage = viewModel.pages.first
        XCTAssertEqual(firstPage?.sections.count, 2)
        let currentModel = firstPage?.sections[safe: 0]
        XCTAssertEqual(currentModel?.sectionTitle, "widget.events.currentTodos".localized())
        XCTAssertEqual(currentModel?.events.map { $0.name }, [
            "current"
        ])
        
        let firstDateModel = firstPage?.sections[safe: 1]
        XCTAssertEqual(
            firstDateModel?.sectionTitle,
            self.refDate.text("date_form.EEE_MMM_d".localized(), timeZone: kst)
        )
        XCTAssertEqual(firstDateModel?.events.map { $0.name }, [
            "todo_at_start"
        ])
    }
    
    func testProvider_whenCurrentTodoNotExists_doNotProvideCurrentTodoDayModel() async throws {
        // given
        let provider = self.makeProvider(withCurrentTodo: false)
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        XCTAssertEqual(viewModel.pages.count, 1)
        XCTAssertEqual(viewModel.pages.first?.sections.count, 2)
        XCTAssertNil(
            viewModel.pages.first?.sections.first(where: { $0.isCurrentTodos  })
        )
    }
    
    func testProvider_whenStartDateEventNotExists_providerWithEmptyDayModel() async throws {
        // given
        let provider = self.makeProvider(withStartDateEvent: false)
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        XCTAssertEqual(viewModel.pages.count, 1)
        let page = viewModel.pages.first
        XCTAssertEqual(page?.sections.count, 3)
        let currentModel = page?.sections[safe: 0]
        XCTAssertEqual(currentModel?.sectionTitle, "widget.events.currentTodos".localized())
        XCTAssertEqual(currentModel?.events.map { $0.name }, [
            "current"
        ])
        
        let firstDateModel = page?.sections[safe: 1]
        XCTAssertEqual(
            firstDateModel?.sectionTitle,
            self.refDate.text("date_form.EEE_MMM_d".localized(), timeZone: kst)
        )
        XCTAssertEqual(firstDateModel?.events.map { $0.name }, [])
        
        let lastDateModel = page?.sections[safe: 2]
        XCTAssertEqual(
            lastDateModel?.sectionTitle,
            self.endDate.text("date_form.EEE_MMM_d".localized(), timeZone: kst)
        )
        XCTAssertEqual(lastDateModel?.events.map { $0.name }, [
            "holiday"
        ])
    }
    
    func testProvider_provideWithEventTagColor() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .large)
        
        // then
        let eventModels = viewModel.pages.flatMap { $0.sections }.flatMap { $0.events }
        let colors = eventModels.map { $0.tagId }
        XCTAssertEqual(colors, [
            .default,   // current todo
            .default,   // start date todo,
            .holiday,   // last date
            .custom("t1"),
            .custom("t2")
        ])
    }
    
    func testProvider_whenEvenThoughEventsIsEmpty_provideFirstDateEvent() async throws {
        // given
        let provider = self.makeProvider(withoutAnyEventsIncludeHoliday: true)
        
        // when
        let viewModel = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        XCTAssertEqual(viewModel.pages.first?.sections.count, 1)
        XCTAssertEqual(
            viewModel.pages.first?.sections.first?.sectionTitle,
            self.refDate.text("EEE, MMM d".localized(), timeZone: kst)
        )
        XCTAssertEqual(viewModel.pages.first?.sections.first?.events.count, 0)
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
            targetEventTagId: .default,
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
        let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        XCTAssertEqual(model.pages.first?.sections.count, 1)
        let todaySection = model.pages.first?.sections.first(where: { $0.sectionTitle == "Fri, Mar 1" })
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
        let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        let page = model.pages.first
        XCTAssertEqual(page?.sections.count, 2)
        let currentSection = page?.sections.first(where: { $0.isCurrentTodos == true })
        XCTAssertEqual(currentSection?.events.count, 1)
        let todaySection = page?.sections.first(where: { $0.sectionTitle == "Fri, Mar 1" })
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
        let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        let page = model.pages.first
        XCTAssertEqual(page?.sections.count, 1)
        let currentSection = page?.sections.first(where: { $0.isCurrentTodos == true })
        XCTAssertEqual(currentSection?.events.count, 3)
        let todaySection = page?.sections.first(where: { $0.sectionTitle == "Fri, Mar 1" })
        XCTAssertNil(todaySection)
    }

    // 전체 이벤트수 제한 걸린경우 필터링
    func testProvider_limitTotalEventCount() async throws {
        // given
        func parameterizeTest(current: Int, today: Int, other: Int, expect: Int) async throws {
            // given
            let provider = self.makeProviderWthStub(
                currentTodosCount: current,
                todayEventCount: today,
                otherDayEventCount: other
            )
            
            // when
            let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .small)
            
            // then
            let totalCount = model.pages.first?.sections.reduce(0) { acc, section in
                return section.events.isEmpty ? acc + 1 : acc + section.events.count
            }
            XCTAssertEqual(totalCount, expect)
        }
        
        // when + then
        try await parameterizeTest(current: 4, today: 1, other: 0, expect: 4)
        try await parameterizeTest(current: 4, today: 1, other: 1, expect: 4)
        try await parameterizeTest(current: 3, today: 0, other: 1, expect: 3)
        try await parameterizeTest(current: 0, today: 4, other: 1, expect: 4)
        try await parameterizeTest(current: 0, today: 1, other: 1, expect: 2)
        try await parameterizeTest(current: 0, today: 1, other: 2, expect: 3)
        try await parameterizeTest(current: 0, today: 1, other: 3, expect: 3)
        try await parameterizeTest(current: 0, today: 1, other: 4, expect: 3)
        try await parameterizeTest(current: 0, today: 3, other: 1, expect: 3)
        try await parameterizeTest(current: 0, today: 0, other: 2, expect: 3)
        try await parameterizeTest(current: 0, today: 0, other: 3, expect: 4)
        try await parameterizeTest(current: 0, today: 0, other: 4, expect: 4)
    }
    
    func testProvider_whenWidgetIsMedium_provideEventsWithPaging() async throws {
        // given
        func parameterizeTest(
            page2EventSourceCount: Int,
            expectPage2Count: Int,
            needBottomSpace: Bool
        ) async throws {
            // given
            let provider = self.makeProviderWthStub(
                currentTodosCount: 0,
                todayEventCount: 4,
                otherDayEventCount: page2EventSourceCount
            )
            
            // when
            let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .medium)
            
            // then
            XCTAssertEqual(model.pages.count, 2)
            let firstPage = model.pages.first; let lastPage = model.pages.last
            XCTAssertEqual(firstPage?.sections.count, 1)
            XCTAssertEqual(firstPage?.sections.first?.events.count, 4)
            XCTAssertEqual(firstPage?.needBottomSpace, false)
            XCTAssertEqual(lastPage?.sections.count, 1)
            XCTAssertEqual(lastPage?.sections.first?.events.count, expectPage2Count)
            XCTAssertEqual(lastPage?.needBottomSpace, needBottomSpace)
        }
        // when + then
        try await parameterizeTest(page2EventSourceCount: 1, expectPage2Count: 1, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 2, expectPage2Count: 2, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 3, expectPage2Count: 3, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 4, expectPage2Count: 4, needBottomSpace: false)
        try await parameterizeTest(page2EventSourceCount: 5, expectPage2Count: 4, needBottomSpace: false)
    }
    
    func testProvider_whenWidgetIsLarge_provideEventsWithPaging() async throws {
        // given
        func parameterizeTest(
            page2EventSourceCount: Int,
            expectPage2Count: Int,
            needBottomSpace: Bool
        ) async throws {
            // given
            let provider = self.makeProviderWthStub(
                currentTodosCount: 0,
                todayEventCount: 11,
                otherDayEventCount: page2EventSourceCount
            )
            
            // when
            let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .large)
            
            // then
            XCTAssertEqual(model.pages.count, 2)
            let firstPage = model.pages.first; let lastPage = model.pages.last
            XCTAssertEqual(firstPage?.sections.count, 1)
            XCTAssertEqual(firstPage?.sections.first?.events.count, 11)
            XCTAssertEqual(firstPage?.needBottomSpace, false)
            
            XCTAssertEqual(lastPage?.sections.count, 1)
            XCTAssertEqual(lastPage?.sections.first?.events.count, expectPage2Count)
            XCTAssertEqual(lastPage?.needBottomSpace, needBottomSpace)
        }
        // when + then
        try await parameterizeTest(page2EventSourceCount: 1, expectPage2Count: 1, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 2, expectPage2Count: 2, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 3, expectPage2Count: 3, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 4, expectPage2Count: 4, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 10, expectPage2Count: 10, needBottomSpace: true)
        try await parameterizeTest(page2EventSourceCount: 11, expectPage2Count: 11, needBottomSpace: false)
        try await parameterizeTest(page2EventSourceCount: 12, expectPage2Count: 11, needBottomSpace: false)
        try await parameterizeTest(page2EventSourceCount: 13, expectPage2Count: 11, needBottomSpace: false)
    }
    
    func testProvider_whenMutiplePageAndPage1SectionIsStartFromPage2_page2FirstSectionIsInvisible() async throws {
        // given
        let provider = self.makeProviderWthStub(
            currentTodosCount: 0, todayEventCount: 5, otherDayEventCount: 3
        )
        
        // when
        let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .medium)
        
        // then
        XCTAssertEqual(model.pages.count, 2)
        let lastPage = model.pages.last
        let firstSectionAtLastPage = lastPage?.sections.first
        XCTAssertNotNil(firstSectionAtLastPage)
        XCTAssertEqual(firstSectionAtLastPage?.sectionTitle, nil)
        XCTAssertEqual(
            (firstSectionAtLastPage?.events.first as? TodoEventCellViewModel)?.eventIdentifier,
            "today:4"
        )
    }
    
    func testProvider_whenNotSmallSize_butEventCountIsNotEnoughForTwoPage_provideOnlyFirstPage() async throws {
        // given
        let provider = self.makeProviderWthStub(
            currentTodosCount: 0, todayEventCount: 1
        )
        
        // when
        let model = try await provider.getEventListViewModel(for: self.refDate, widgetSize: .medium)
        
        // then
        XCTAssertEqual(model.pages.count, 1)
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
            targetEventTagId: .default,
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
        let viewModel = try await usecase.getEventListViewModel(for: self.refDate, widgetSize: .small)
        
        // then
        let allEvents = viewModel.pages.first?.sections.flatMap { $0.events } ?? []
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
        
        func fetchForemostEvent() async throws -> ForemostEvent {
            return .init(foremostEvent: nil, tag: nil)
        }
        
        func fetchNextEvent(
            _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
        ) async throws -> TodayNextEvent? {
            return nil
        }
    }
    
    private func makeProviderWithStubUnsortedEvents() -> EventListWidgetViewModelProvider {
        
        let fetchUsecase = UnSortedStubEventsFetchUsecase(refDate: self.refDate)
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        return .init(
            targetEventTagId: .default,
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
            for: self.refDate, widgetSize: .large
        )
        
        // then
        let page = viewModel.pages.first
        XCTAssertEqual(page?.sections.count, 2)
        let currents = page?.sections.first(where: { $0.isCurrentTodos })
        let section0 = page?.sections.first(where: { !$0.isCurrentTodos })
        XCTAssertEqual(currents?.events.map { $0.eventIdentifier}, [
            "current-1", "current-30", "current-90",
        ])
        XCTAssertEqual(section0?.events.map { $0.eventIdentifier }, [
            "todo-10", "todo-20", "todo-100"
        ])
    }
}


extension EventListWidgetViewModelProviderTests {
    
    private func makeProviderWithMultipleTagHasEvents(
        select tagId: EventTagId
    ) -> EventListWidgetViewModelProvider {
        
        final class EventsWithTagFetchUescase: CalendarEventFetchUsecase {
            
            func fetchEvents(in range: Range<TimeInterval>, _ timeZone: TimeZone) async throws -> CalendarEvents {
                let kst = TimeZone(abbreviation: "KST")!
                let currents = (0..<10).map { int -> TodoEvent in
                    let tagId: EventTagId = int % 3 == 0
                        ? .custom("t3") : int % 5 == 0 
                        ? .custom("t5") : .default
                    return TodoEvent(uuid: "\(int)", name: "current")
                        |> \.eventTagId .~ tagId
                }
                .map { TodoCalendarEvent($0, in: kst) }
                
                let events = CalendarEvents(currentTodos: currents, eventWithTimes: [], customTagMap: [:])
                return events
            }
            
            func fetchForemostEvent() async throws -> ForemostEvent {
                return .init(foremostEvent: nil, tag: nil)
            }
            
            func fetchNextEvent(
                _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
            ) async throws -> TodayNextEvent? {
                return nil
            }
        }
        
        let fetchUsecase = EventsWithTagFetchUescase()
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        return .init(
            targetEventTagId: tagId,
            eventsFetchUsecase: fetchUsecase,
            appSettingRepository: appSettingRepository,
            calendarSettingRepository: calendarSettingRepository
        )
    }
    
    func testProvider_provideEventsWithFilteringByTag() async throws {
        // given
        func parameterizeTest(
            _ target: EventTagId,
            expectIds: [String]
        ) async throws {
            // given
            let provider = self.makeProviderWithMultipleTagHasEvents(select: target)
            
            // when
            let vm = try await provider.getEventListViewModel(
                for: self.refDate, widgetSize: .large
            )
            
            // then
            let currents = vm.pages.first?.sections.first(where: { $0.isCurrentTodos })
            let identifiers = currents?.events.map { $0.eventIdentifier }
            XCTAssertEqual(identifiers, expectIds)
        }
        
        // when + then
        try await parameterizeTest(.custom("t3"), expectIds: ["0", "3", "6", "9"])
        try await parameterizeTest(.custom("t5"), expectIds: ["5"])
        try await parameterizeTest(.default, expectIds: (0..<10).map { "\($0)" })
    }
}
