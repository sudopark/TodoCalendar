//
//  CalendarPagerViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/06/28.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Scenes
import TestDoubles
import UnitTestHelpKit

@testable import CalendarScenes


class CalendarPagerViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyHolidayUsecase: StubHolidayUsecase!
    private var spyTodoUsecase: PrivateSpyTodoEventUsecase!
    private var spyScheduleUsecase: PrivateSpyScheduleEventUsecase!
    private var stubSettingUsecase: StubCalendarSettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyHolidayUsecase = .init()
        self.spyRouter = .init()
        self.spyTodoUsecase = .init()
        self.spyScheduleUsecase = .init()
        self.stubSettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyHolidayUsecase = nil
        self.spyRouter = nil
        self.spyTodoUsecase = nil
        self.spyScheduleUsecase = nil
        self.stubSettingUsecase = nil
    }
    
    private func makeViewModel(
        today: CalendarComponent.Day = .init(year: 2023, month: 02, day: 02, weekDay: 5)
    ) -> CalendarPagerViewModelImple {
        
        let calendarUsecase = StubCalendarUsecase(today: today)
        self.stubSettingUsecase.prepare()
        
        let viewModel = CalendarPagerViewModelImple(
            calendarUsecase: calendarUsecase,
            calendarSettingUsecase: self.stubSettingUsecase,
            holidayUsecase: self.spyHolidayUsecase,
            todoEventUsecase: self.spyTodoUsecase,
            scheduleEventUsecase: self.spyScheduleUsecase
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
    
    private func range(_ start: (Int, Int, Int),
                       _ end: (Int, Int, Int)) -> Range<TimeInterval> {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        let startCompos = DateComponents(year: start.0, month: start.1, day: start.2, hour: 0, minute: 0, second: 0)
        let endCompos = DateComponents(year: end.0, month: end.1, day: end.2, hour: 23, minute: 59, second: 59)
        
        let start = calendar.date(from: startCompos)!
        let end = calendar.date(from: endCompos)!
        return start.timeIntervalSince1970..<end.timeIntervalSince1970
    }
    
    func testViewModel_whenRangeChangeAndNewMonthAppened_reloadTodoEventsInTotalPeriod() {
        // given
        let expect = expectation(description: "calendar가 조회중인 전체 조회 기간이 길어지면 스케줄 이벤트 다시 조회")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 04, weekDay: 3)
        )
        
        // when
        let totalRange = self.range((2023, 08, 01), (2024, 1, 31))
        let source = self.spyTodoUsecase.todoEvents(in: totalRange)
        let todoLists = self.waitOutputs(expect, for: source) {
            // 전체 범위 => 9~11월
            
            // 전체 범위 => 8~11월, 신규 8~9
            viewModel.focusMoveToPreviousMonth()
            
            // 전체범위 변동 없음 => 8~11
            viewModel.focusMoveToNextMonth()
            
            // 전체 범위 => 8~12월, 신규 11~12
            viewModel.focusMoveToNextMonth()
            
            // 전체 범위 => 8~다음년도1월, 신규 12~1
            viewModel.focusMoveToNextMonth()
        }
        
        // then
        let todoIdLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(todoIdLists, [
            ["kst-month: 9~11"],
            ["kst-month: 9~11", "kst-month: 8~9"],
            ["kst-month: 9~11", "kst-month: 8~9", "kst-month: 11~12"],
            ["kst-month: 9~11", "kst-month: 8~9", "kst-month: 11~12", "kst-month: 12~1"]
        ])
    }
    
    func testViewModel_whenRangeChangeAndNewMonthAppened_reloadScheduleEventsInTotalPeriod() {
        // given
        let expect = expectation(description: "calendar가 조회중인 전체 조회 기간이 길어지면 시간정보 있는 할일 이벤트 다시 조회")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 04, weekDay: 3)
        )
        
        // when
        let totalRange = self.range((2023, 08, 01), (2024, 1, 31))
        let source = self.spyScheduleUsecase.scheduleEvents(in: totalRange)
        let scheduleLists = self.waitOutputs(expect, for: source) {
            // 전체 범위 => 9~11월
            
            // 전체 범위 => 8~11월, 신규 8~9
            viewModel.focusMoveToPreviousMonth()
            
            // 전체범위 변동 없음 => 8~11
            viewModel.focusMoveToNextMonth()
            
            // 전체 범위 => 8~12월, 신규 11~12
            viewModel.focusMoveToNextMonth()
            
            // 전체 범위 => 8~다음년도1월, 신규 12~1
            viewModel.focusMoveToNextMonth()
        }
        
        // then
        let scheduleIdLists = scheduleLists.map { ss in ss.map { $0.uuid } }
        XCTAssertEqual(scheduleIdLists, [
            ["kst-month: 9~11"],
            ["kst-month: 9~11", "kst-month: 8~9"],
            ["kst-month: 9~11", "kst-month: 8~9", "kst-month: 11~12"],
            ["kst-month: 9~11", "kst-month: 8~9", "kst-month: 11~12", "kst-month: 12~1"]
        ])
    }
    
    // timeZone 변경시도 테스트 추가해야함
    func testViewModel_whenTimeZoneChanged_refreshNotCheckedRange() {
        // given
        let expect = expectation(description: "timeZone 변경시에 새로운 구간에 대한 todo 이벤트 조회")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 4, weekDay: 2)
        )
        
        // when
        let totalRange = self.range((2023, 08, 01), (2024, 1, 31))
        let source = self.spyTodoUsecase.todoEvents(in: totalRange)
        let todoLists = self.waitOutputs(expect, for: source) {
            // 최초 9~11월 나몸
            
            // timeZone pdt로 변경 => 현재보다 16시간 만큼 미래시간으로 지정됨
            // 달력의 마지막날인 2023-11-30일 23:59:59에서 pdt로 빼낸 interval을 kst로 변경하면 12월 1일임
            self.stubSettingUsecase.selectTimeZone(TimeZone(abbreviation: "PDT")!)
        }
        
        // then
        let todoIdLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(todoIdLists, [
            ["kst-month: 9~11"],
            ["kst-month: 9~11", "kst-month: 11~12"]
        ])
    }
}

private extension CalendarPagerViewModelImpleTests {
    
    class SpyRouter: CalendarPagerViewRouting, @unchecked Sendable {
        
        var spyInteractors: [SpyMonthInteractor] = []
        var didInitialMonthsAttached: (() -> Void)?
        func attachInitialMonths(_ months: [CalendarMonth]) -> [CalendarSingleMonthInteractor] {
            let interactors = months.map { SpyMonthInteractor(currentMonth: $0) }
            self.spyInteractors = interactors
            self.didInitialMonthsAttached?()
            return interactors
        }
    }
    
    class SpyMonthInteractor: CalendarSingleMonthInteractor, @unchecked Sendable {
        
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
    
    class PrivateSpyTodoEventUsecase: StubTodoEventUsecase {
        
        private let todoEventsInRange = CurrentValueSubject<[TodoEvent]?, Never>(nil)
        override func refreshTodoEvents(in period: Range<TimeInterval>) {
            let calendar = Calendar(identifier: .gregorian)
                |> \.timeZone .~ TimeZone(abbreviation: "KST")!
            let startMonth = calendar.component(.month, from: Date(timeIntervalSince1970: period.lowerBound))
            let endMonth = calendar.component(.month, from: Date(timeIntervalSince1970: period.upperBound))
            
            let newTodo = TodoEvent(uuid: "kst-month: \(startMonth)~\(endMonth)", name: "dummy")
                |> \.time .~ EventTime.at(period.lowerBound)
            let newTodos = (self.todoEventsInRange.value ?? []) <> [newTodo]
            self.todoEventsInRange.send(newTodos)
        }
        
        override func todoEvents(in period: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], Never> {
            return self.todoEventsInRange
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }
    }
    
    class PrivateSpyScheduleEventUsecase: StubScheduleEventUsecase {
        
        private let scheduleEventsInRange = CurrentValueSubject<[ScheduleEvent]?, Never>(nil)
        override func refreshScheduleEvents(in period: Range<TimeInterval>) {
            let calendar = Calendar(identifier: .gregorian)
                |> \.timeZone .~ TimeZone(abbreviation: "KST")!
            let startMonth = calendar.component(.month, from: Date(timeIntervalSince1970: period.lowerBound))
            let endMonth = calendar.component(.month, from: Date(timeIntervalSince1970: period.upperBound))
            
            let newOne = ScheduleEvent(
                uuid: "kst-month: \(startMonth)~\(endMonth)",
                name: "dummy",
                time: .at(period.lowerBound)
            )
            let newSchedules = (self.scheduleEventsInRange.value ?? []) <> [newOne]
            self.scheduleEventsInRange.send(newSchedules)
        }
        
        override func scheduleEvents(in period: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], Never> {
            return self.scheduleEventsInRange
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }
    }
}
