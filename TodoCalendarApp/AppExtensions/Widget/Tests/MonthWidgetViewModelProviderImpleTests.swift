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
        shouldFailLoadEvent: Bool = false
    ) -> MonthWidgetViewModelProviderImple {
        let calendarUsecase = StubCalendarUsecase()
        let settingRepository = StubCalendarSettingRepository()
        settingRepository.saveTimeZone(TimeZone(abbreviation: "KST")!)
        
        let todoRepository = PrivateStubTodoRepository()
        todoRepository.isEmptyEvent = isEmptyEvent
        todoRepository.shouldFailLoadTodosInRange = shouldFailLoadEvent
        
        let scheduleRepostory = PrivateStubScheduleRepository()
        scheduleRepostory.isEmptyEvent = isEmptyEvent
        scheduleRepostory.shouldFailLoad = shouldFailLoadEvent
        
        return MonthWidgetViewModelProviderImple(
            calendarUsecase: calendarUsecase,
            settingRepository: settingRepository,
            todoRepository: todoRepository,
            scheduleRepository: scheduleRepostory
        )
    }
}

extension MonthWidgetViewModelProviderImpleTests {
    
    // assert sample view model
    func testProvider_makeSampleModel() {
        // given
        let provider = self.makeProvider()
        
        // when
        let sample = try? provider.makeSampleMonthViewModel(self.dummyNow)
        
        // then
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.todayIdentifier, "2024-3-10")
        XCTAssertEqual(sample?.hasEventDaysIdentifiers, [
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
