//
//  CalendarPagerViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/06/28.
//

import XCTest
import Domain
import Combine
import TestDoubles
import UnitTestHelpKit

@testable import CalendarScenes


class CalendarPagerViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyHolidayUsecase: StubHolidayUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyHolidayUsecase = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyHolidayUsecase = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel(
        today: CalendarComponent.Day = .init(year: 2023, month: 02, day: 02, weekDay: 5)
    ) -> CalendarPagerViewModelImple {
        
        let calendarUsecase = StubCalendarUsecase(today: today)
        
        let viewModel = CalendarPagerViewModelImple(
            calendarUsecase: calendarUsecase,
            holidayUsecase: self.spyHolidayUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

// MARK: - 초기 구성 및 페이징

extension CalendarPagerViewModelImpleTests {
    
    func testViewModel_whenPrepare_prepareInitalMonthsByAroundCurrentMonth() {
        // given
        let expect = expectation(description: "prepare하면 현재 날짜 기준으로 하위 월 구성함")
        let viewModel = self.makeViewModel()
        self.spyRouter.didInitialMonthsAttached = { expect.fulfill() }
        
        // when
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let preparedMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(preparedMonths, [
            .init(year: 2023, month: 1),
            .init(year: 2023, month: 2),
            .init(year: 2023, month: 3)
        ])
    }
    
    private func makeViewModelWithInitialSetup(_ today: CalendarComponent.Day) -> CalendarPagerViewModelImple {
        // given
        let expect = expectation(description: "초기 월 세팅 대기")
        let viewModel = self.makeViewModel(today: today)
        self.spyRouter.didInitialMonthsAttached = { expect.fulfill() }
        
        // when
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        return viewModel
    }
    
    // focus 과거날짜로 이동시 -> month 구성 -1하고 전파
    func testViewModel_whenFocusChangedToPast_updateMonths() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 02, day: 02, weekDay: 5)
        )
        
        // when
        viewModel.focusMoveToPreviousMonth()
        
        // then
        let months = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(months, [
            .init(year: 2022, month: 12),
            .init(year: 2023, month: 01),
            .init(year: 2023, month: 02)
        ])
    }
    
    // focus 미래 날짜로 이동시 -> month 구성 +1하고 전파
    func testViewModel_whenFocusChangedToFuture_updateMonths() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 11, day: 23, weekDay: 5)
        )
        
        // when
        viewModel.focusMoveToNextMonth()
        
        // then
        let months = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(months, [
            .init(year: 2023, month: 11),
            .init(year: 2023, month: 12),
            .init(year: 2024, month: 01)
        ])
    }
}

// MARK: - 기타 정보 갱신

extension CalendarPagerViewModelImpleTests {
    
    func testViewModel_whenFocusChangedToNewYear_refreshTheYearsHolidays() {
        // given
        let expect = expectation(description: "calendar가 조회한 년도 중 새로운 년도 추가시에 새로운 년도의 공휴일 refresh -> 2023, 2022, 2021년 조회할것임")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 02, day: 02, weekDay: 5)
        )
        
        // when
        let holidaysPerYears = self.waitOutputs(expect, for: self.spyHolidayUsecase.holidays()) {
            // 2021년까지 준비되도록 스크롤
            (0..<13).forEach { _ in
                viewModel.focusMoveToPreviousMonth()
            }
        }
        
        // then
        let currentViewingMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(currentViewingMonths, [
            .init(year: 2021, month: 12),
            .init(year: 2022, month: 1),
            .init(year: 2022, month: 2)
        ])
        let holidayLoadedYears = holidaysPerYears.map { $0.keys }.map { $0.sorted() }
        XCTAssertEqual(holidayLoadedYears, [
            [2023],
            [2022, 2023],
            [2021, 2022, 2023]
        ])
    }
    
    // calendar가 조회중인 전체 조회 기간이 길어지면 스케줄 이벤트 다시 조회
    
    // calendar가 조회중인 전체 조회 기간이 길어지면 시간정보 있는 할일 이벤트 다시 조회
}

private extension CalendarPagerViewModelImpleTests {
    
    class SpyRouter: CalendarPagerViewRouting, @unchecked Sendable {
        
        var spyInteractors: [SpyMonthInteractor] = []
        var didInitialMonthsAttached: (() -> Void)?
        func attachInitialMonths(_ months: [CalendarMonth]) -> [CalendarMonthInteractor] {
            let interactors = months.map { SpyMonthInteractor(currentMonth: $0) }
            self.spyInteractors = interactors
            self.didInitialMonthsAttached?()
            return interactors
        }
    }
    
    class SpyMonthInteractor: CalendarMonthInteractor, @unchecked Sendable {
        
        var currentMonth: CalendarMonth
        init(currentMonth: CalendarMonth) {
            self.currentMonth = currentMonth
        }
        
        func updateMonthIfNeed(_ newMonth: CalendarMonth) {
            self.currentMonth = newMonth
        }
        
        var didHolidayChanged: Bool?
        func holidayChanged(_ holidays: [Int : [Holiday]]) {
            self.didHolidayChanged = true
        }
    }
}
