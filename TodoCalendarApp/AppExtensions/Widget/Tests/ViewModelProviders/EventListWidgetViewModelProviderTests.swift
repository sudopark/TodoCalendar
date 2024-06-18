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
        let viewModel = try await provider.getEventListViewModel(for: self.refDate)
        
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
        let viewModel = try await provider.getEventListViewModel(for: self.refDate)
        
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
        let viewModel = try await provider.getEventListViewModel(for: self.refDate)
        
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
        let viewModel = try await provider.getEventListViewModel(for: self.refDate)
        
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
        let viewModel = try await provider.getEventListViewModel(for: self.refDate)
        
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
        let viewModel = try await usecase.getEventListViewModel(for: self.refDate)
        
        // then
        let allEvents = viewModel.lists.flatMap { $0.events }
        let refDateEvent = allEvents.first as? TodoEventCellViewModel
        XCTAssertEqual(refDateEvent?.name, "allday todo")
        XCTAssertEqual(allEvents.count, 1)
    }
}
