//
//  MonthWidgetViewModelProviderImpleTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 5/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import TodoCalendarAppWidget


class MonthWidgetViewModelProviderImpleTests: BaseTestCase {
    
    private var dummyNow: Date {
        let calendar = Calendar(identifier: .gregorian)
            |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        return calendar.dateBySetting(from: Date()) {
            $0.year = 2023
            $0.month = 9
            $0.day = 8
        }!
    }
    
    private func makeProvider(
        isEmptyEvent: Bool = false,
        shouldFailLoadEvent: Bool = false,
        shouldFailLoadHolidays: Bool = false
    ) -> MonthWidgetViewModelProvider {
        let calendarUsecase = StubCalendarUsecase()
        let settingRepository = StubCalendarSettingRepository()
        settingRepository.saveTimeZone(TimeZone(abbreviation: "KST")!)
        
        let holidayUsecase = PrivateStubHolidayUsecase()
        holidayUsecase.shouldFailLoad = shouldFailLoadHolidays
        
        let todoRepository = PrivateStubTodoRepository()
        todoRepository.isEmptyEvent = isEmptyEvent
        todoRepository.shouldFailLoadTodosInRange = shouldFailLoadEvent
        
        let scheduleRepostory = PrivateStubScheduleRepository()
        scheduleRepostory.isEmptyEvent = isEmptyEvent
        scheduleRepostory.shouldFailLoad = shouldFailLoadEvent
        
        return MonthWidgetViewModelProvider(
            calendarUsecase: calendarUsecase,
            holidayUsecase: holidayUsecase,
            settingRepository: settingRepository,
            todoRepository: todoRepository,
            scheduleRepository: scheduleRepostory
        )
    }
}

extension MonthWidgetViewModelProviderImpleTests {
    
    // assert sample view model
    func test_makeSampleModel() throws {
        // given
        
        // when
        let sample = try MonthWidgetViewModel.makeSample()
        
        // then
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample.todayIdentifier, "2024-3-10")
        XCTAssertEqual(sample.hasEventDaysIdentifiers, [
            "2024-3-4", "2024-3-17", "2024-3-28"
        ])
    }
    
    // load model with event
    func testProvider_getModelWithEvent() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getMonthViewModel(self.dummyNow)
        
        // then
        XCTAssertEqual(model.todayIdentifier, "2023-9-8")
        XCTAssertEqual(model.hasEventDaysIdentifiers, [
            "2023-8-27", "2023-9-30"
        ])
    }
    
    // load model without events
    func testProvider_getModelWithoutEvent() async throws {
        // given
        let provider = self.makeProvider(isEmptyEvent: true)
        
        // when
        let model = try await provider.getMonthViewModel(self.dummyNow)
        
        // then
        XCTAssertEqual(model.todayIdentifier, "2023-9-8")
        XCTAssertEqual(model.hasEventDaysIdentifiers, [])
    }
    
    // when load model failed during load events ignore
    func testProvider_whenLoadEventsFail_ignore() async throws {
        // given
        let provider = self.makeProvider(shouldFailLoadEvent: true)
        
        // when
        let model = try await provider.getMonthViewModel(self.dummyNow)
        
        // then
        XCTAssertEqual(model.todayIdentifier, "2023-9-8")
        XCTAssertEqual(model.hasEventDaysIdentifiers, [])
    }
    
    // provide model with holiday info
    func testProvider_provideViewModelWithHolidayInfo() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getMonthViewModel(self.dummyNow)
        
        // then
        let holidays = model.weeks.flatMap { $0.days }.filter { $0.accentDay == .holiday }
        let ids = holidays.map { $0.identifier }
        XCTAssertEqual(ids, [
            "2023-9-12", "2023-9-13", "2023-9-14"
        ])
    }
    
    func testProvider_whenLoadHolidaysFailed_ignore() async throws {
        // given
        let provider = self.makeProvider(shouldFailLoadHolidays: true)
        
        // when
        let model = try await provider.getMonthViewModel(self.dummyNow)
        
        // then
        let holidays = model.weeks.flatMap { $0.days }.filter { $0.accentDay == .holiday }
        let ids = holidays.map { $0.identifier }
        XCTAssertEqual(ids, [])
    }
}


private final class PrivateStubTodoRepository: StubTodoEventRepository {
    
    var isEmptyEvent: Bool = false
    override func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error> {
        
        guard self.shouldFailLoadTodosInRange == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        
        guard self.isEmptyEvent == false
        else {
            return Just([]).mapAsAnyError().eraseToAnyPublisher()
        }
        
        let todoAtStartDate = TodoEvent(uuid: "todo", name: "some")
            |> \.time .~ .at(range.lowerBound)
        return Just([todoAtStartDate]).mapAsAnyError().eraseToAnyPublisher()
    }
}

private final class PrivateStubScheduleRepository: StubScheduleEventRepository {
    
    var isEmptyEvent: Bool = false
    
    override func loadScheduleEvents(in range: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], any Error> {
        
        guard self.shouldFailLoad == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        
        guard self.isEmptyEvent == false
        else {
            return Just([]).mapAsAnyError().eraseToAnyPublisher()
        }
        
        let eventAtLastDate = ScheduleEvent(uuid: "schedule", name: "some", time: .at(range.upperBound-1))
        return Just([eventAtLastDate]).mapAsAnyError().eraseToAnyPublisher()
    }
}


private final class PrivateStubHolidayUsecase: StubHolidayUsecase {
    
    var shouldFailLoad: Bool = false
    
    override func loadHolidays(_ year: Int) async throws -> [Holiday] {
        
        guard shouldFailLoad == false
        else {
            throw RuntimeError("failed")
        }
        
        guard self.currentSelectedCountrySubject.value != nil
        else {
            throw RuntimeError("no current country")
        }
        let holidays: [Holiday] = [
            .init(dateString: "2023-09-12", localName: "some", name: "name"),
            .init(dateString: "2023-09-13", localName: "some", name: "name"),
            .init(dateString: "2023-09-14", localName: "some", name: "name")
        ]
        return holidays
    }
}
