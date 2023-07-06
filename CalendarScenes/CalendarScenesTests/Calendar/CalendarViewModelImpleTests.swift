//
//  CalendarViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/07/05.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes


class CalendarViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
    }
    
    private func makeViewModel() -> CalendarViewModelImple {
        let calendarUsecase = PrivateStubCalendarUsecase(
            today: .init(year: 2023, month: 09, day: 10, weekDay: 1)
        )
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        let todoUsecase = StubTodoEventUsecase()
        let scheduleUsecase = StubScheduleEventUsecase()
        
        let viewModel = CalendarViewModelImple(
            calendarUsecase: calendarUsecase,
            calendarSettingUsecase: settingUsecase,
            todoUsecase: todoUsecase,
            scheduleEventUsecase: scheduleUsecase
        )
        return viewModel
    }
}


// MARK: - provide components

extension CalendarViewModelImpleTests {
    
    func testViewModel_whenUpdateMonth_provideCalendarWeeks() {
        // given
        let expect = expectation(description: "지정된 달의 날짜 반환")
        let viewModel = self.makeViewModel()
        
        // when
        let weeks = self.waitFirstOutput(expect, for: viewModel.weekModels) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
        } ?? []
        
        // then
        XCTAssertEqual(
            weeks.map { ws in ws.days.map { $0.day } },
            CalendarComponent.dummy2023_9().weeks.map { ws in ws.days.map { $0.day } }
        )
        XCTAssertEqual(weeks.map { ws in ws.days.map { $0.isNotCurrentMonth }}, [
            [true, true, true, true, true, false, false],
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7)
        ])
    }
    
    func testViewModel_whenMonthUpdated_updateCalendarWeeks() {
        // given
        let expect = expectation(description: "지장된 달 변경")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let weekLists = self.waitOutputs(expect, for: viewModel.weekModels) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))    // ignore
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 8))
        }
        
        // then
        let weeksFor9 = weekLists.first ?? []
        let weeksFor8 = weekLists.last ?? []
        XCTAssertEqual(
            weeksFor9.map { ws in ws.days.map { $0.day } },
            CalendarComponent.dummy2023_9().weeks.map { ws in ws.days.map { $0.day } }
        )
        XCTAssertEqual(weeksFor9.map { ws in ws.days.map { $0.isNotCurrentMonth }}, [
            [true, true, true, true, true, false, false],
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7)
        ])
        
        XCTAssertEqual(
            weeksFor8.map { ws in ws.days.map { $0.day } },
            CalendarComponent.dummy2023_8().weeks.map { ws in ws.days.map { $0.day } }
        )
        XCTAssertEqual(weeksFor8.map { ws in ws.days.map { $0.isNotCurrentMonth }}, [
            [true, true, false, false, false, false, false],
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            [false, false, false, false, false, true, true]
        ])
    }
}


// MARK: - selected day

extension CalendarViewModelImpleTests {
 
    func testViewModel_whenCurrentMonthIsEqualTodayMonth_defaultSelectionDayIsToday() {
        // given
        let expect = expectation(description: "지정된 달이 오늘과 같은 달이면 현재 날짜 디폴트로 선택")
        let viewModel = self.makeViewModel()
        
        // when
        let selected = self.waitFirstOutput(expect, for: viewModel.currentSelectDayIdentifier) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
        }
        
        // then
        XCTAssertEqual(selected, "2023-9-10")
    }
    
    func testViewModel_whenCurrentMonthIsNotEqualTodayMonth_defaultSelectionDayIsMonthFirstDay() {
        // given
        let expect = expectation(description: "지정된 달이 오늘과 같은 달이 아니면 1일 디폴트로 선택")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let selecteds = self.waitOutputs(expect, for: viewModel.currentSelectDayIdentifier) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 8))
        }
        
        // then
        XCTAssertEqual(selecteds, [
            "2023-9-10", "2023-8-1"
        ])
    }
    
    func testViewModel_whenSelectDay_updateSelectedDay() {
        // given
        let expect = expectation(description: "날짜 선택시에 해당 날짜가 선택한 날짜가 됨")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let selecteds = self.waitOutputs(expect, for: viewModel.currentSelectDayIdentifier) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
            viewModel.select(
                .init(year: 2023, month: 9, day: 23, isNotCurrentMonth: false)
            )
        }
        
        // then
        XCTAssertEqual(selecteds, [
            "2023-9-10", "2023-9-23"
        ])
    }
}


// MARK: - test events

extension CalendarViewModelImpleTests {
    
}

// MARK: - doubles

extension CalendarViewModelImpleTests {
    
    private class PrivateStubCalendarUsecase: StubCalendarUsecase {
        
        override func components(for month: Int, of year: Int) -> AnyPublisher<CalendarComponent, Never> {
            if month == 9 && year == 2023 {
                let dummy = CalendarComponent.dummy2023_9()
                return Just(dummy).eraseToAnyPublisher()
            } else if month == 8 && year == 2023 {
                let dummy = CalendarComponent.dummy2023_8()
                return Just(dummy).eraseToAnyPublisher()
            } else {
                return Empty().eraseToAnyPublisher()
            }
        }
    }
}
