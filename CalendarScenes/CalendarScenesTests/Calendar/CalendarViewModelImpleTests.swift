//
//  CalendarViewModelImpleTests.swift
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


class CalendarViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyHolidayUsecase: StubHolidayUsecase!
    private var spyTodoUsecase: PrivateSpyTodoEventUsecase!
    private var spyScheduleUsecase: PrivateSpyScheduleEventUsecase!
    private var stubSettingUsecase: StubCalendarSettingUsecase!
    private var spyEventTagUsecase: PrivateSpyEventTagUsecase!
    private var spyListener: SpyListener!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyHolidayUsecase = .init()
        self.spyRouter = .init()
        self.spyTodoUsecase = .init()
        self.spyScheduleUsecase = .init()
        self.stubSettingUsecase = .init()
        self.spyEventTagUsecase = .init()
        self.spyListener = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyHolidayUsecase = nil
        self.spyRouter = nil
        self.spyTodoUsecase = nil
        self.spyScheduleUsecase = nil
        self.stubSettingUsecase = nil
        self.spyEventTagUsecase = nil
        self.spyListener = nil
    }
    
    private func makeViewModel(
        today: CalendarComponent.Day = .init(year: 2023, month: 02, day: 02, weekDay: 5)
    ) -> CalendarViewModelImple {
        
        let calendarUsecase = StubCalendarUsecase(today: today)
        
        let viewModel = CalendarViewModelImple(
            calendarUsecase: calendarUsecase,
            calendarSettingUsecase: self.stubSettingUsecase,
            holidayUsecase: self.spyHolidayUsecase,
            todoEventUsecase: self.spyTodoUsecase,
            scheduleEventUsecase: self.spyScheduleUsecase,
            eventTagUsecase: self.spyEventTagUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }
}

// MARK: - 초기 구성 및 페이징

extension CalendarViewModelImpleTests {
    
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
    
    func testViewModel_whenPrepare_prepareHoliday() {
        // given
        let expect = expectation(description: "prepare시에 holiday도 준비 -> 현재 국가정보 반환됨")
        let viewModel = self.makeViewModel()
        
        // when
        let currentCountry = self.waitFirstOutput(expect, for: self.spyHolidayUsecase.currentSelectedCountry.removeDuplicates(by: { $0.code == $1.code })) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(currentCountry?.code, "KST")
    }
    
    func testViewModel_whenPrepre_bindRequireEventTagRefreshing() {
        // given
        let expect = expectation(description: "prepare 시에 필요 이벤트 tag 정보 refresh 바인딩")
        let viewModel = self.makeViewModel()
        self.spyEventTagUsecase.didPrepared = {
            expect.fulfill()
        }
        
        // when
        viewModel.prepare()
        
        // then
        self.wait(for: [expect], timeout: 0.001)
    }
    
    func testViewModel_whenPrepare_refreshCurrentTodos() {
        // given
        let expect = expectation(description: "prepare시에 concurrent todo refresh")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        self.spyTodoUsecase.stubCurrentTodos = [TodoEvent(uuid: "current", name: "some")]
        
        // when
        let currentTodos = self.waitOutputs(expect, for: self.spyTodoUsecase.currentTodoEvents) {
            viewModel.prepare()
        }
        
        // then
        let todoIds = currentTodos.map { ts in ts.map { $0.uuid }}
        XCTAssertEqual(todoIds, [
            [], ["current"]
        ])
    }
    
    private func makeViewModelWithInitialSetup(_ today: CalendarComponent.Day) -> CalendarViewModelImple {
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
    
    
    func testViewModel_whenUpdateFocus_updateMonths() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        func parameterizeTest(expect months: [CalendarMonth], _ action: () -> Void) {
            action()
            
            let currentMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
            XCTAssertEqual(currentMonths, months)
        }
        
        // move next
        parameterizeTest(expect: [
            .init(year: 2023, month: 10), .init(year: 2023, month: 08), .init(year: 2023, month: 09)
        ]) { viewModel.focusChanged(from: 1, to: 2) }
        
        parameterizeTest(expect: [
            .init(year: 2023, month: 10), .init(year: 2023, month: 11), .init(year: 2023, month: 09)
        ]) { viewModel.focusChanged(from: 2, to: 0) }
        
        parameterizeTest(expect: [
            .init(year: 2023, month: 10), .init(year: 2023, month: 11), .init(year: 2023, month: 12)
        ]) { viewModel.focusChanged(from: 0, to: 1) }
        
        parameterizeTest(expect: [
            .init(year: 2024, month: 01), .init(year: 2023, month: 11), .init(year: 2023, month: 12)
        ]) { viewModel.focusChanged(from: 1, to: 2) }
        
        parameterizeTest(expect: [
            .init(year: 2024, month: 01), .init(year: 2024, month: 02), .init(year: 2023, month: 12)
        ]) { viewModel.focusChanged(from: 2, to: 0) }
        
        // move previous
        parameterizeTest(expect: [
            .init(year: 2024, month: 01), .init(year: 2023, month: 11), .init(year: 2023, month: 12)
        ]) { viewModel.focusChanged(from: 0, to: 2) }
        
        parameterizeTest(expect: [
            .init(year: 2023, month: 10), .init(year: 2023, month: 11), .init(year: 2023, month: 12)
        ]) { viewModel.focusChanged(from: 2, to: 1) }
        
        parameterizeTest(expect: [
            .init(year: 2023, month: 10), .init(year: 2023, month: 11), .init(year: 2023, month: 09)
        ]) { viewModel.focusChanged(from: 1, to: 0) }
        
        parameterizeTest(expect: [
            .init(year: 2023, month: 10), .init(year: 2023, month: 08), .init(year: 2023, month: 09)
        ]) { viewModel.focusChanged(from: 0, to: 2) }
        
        parameterizeTest(expect: [
            .init(year: 2023, month: 07), .init(year: 2023, month: 08), .init(year: 2023, month: 09)
        ]) { viewModel.focusChanged(from: 2, to: 1) }
    }
    
    func testViewModel_whenFocusedMonthChanged_notify() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        func parameterizeTest(
            _ month: CalendarMonth,
            _ isCurrent: Bool,
            _ action: () -> Void
        ) {
            let expect = expectation(description: "현재 포커스된 달 조회 변경")
            var pair: (CalendarMonth, Bool)?
            self.spyListener.didMonthChanged = { focuse, flag in
                pair = (focuse, flag)
                expect.fulfill()
            }
            action()
            self.wait(for: [expect], timeout: self.timeout)
            
            XCTAssertEqual(pair?.0, month)
            XCTAssertEqual(pair?.1, isCurrent)
        }
        
        // when + then
        parameterizeTest(.init(year: 2023, month: 09), false) {
            viewModel.focusChanged(from: 1, to: 2)
        }
        parameterizeTest(.init(year: 2023, month: 10), false) {
            viewModel.focusChanged(from: 2, to: 0)
        }
        parameterizeTest(.init(year: 2023, month: 11), false) {
            viewModel.focusChanged(from: 0, to: 1)
        }
        parameterizeTest(.init(year: 2023, month: 10), false) {
            viewModel.focusChanged(from: 1, to: 0)
        }
        parameterizeTest(.init(year: 2023, month: 09), false) {
            viewModel.focusChanged(from: 0, to: 2)
        }
        parameterizeTest(.init(year: 2023, month: 08), true) {
            viewModel.focusChanged(from: 2, to: 1)
        }
        parameterizeTest(.init(year: 2023, month: 07), false) {
            viewModel.focusChanged(from: 1, to: 0)
        }
        parameterizeTest(.init(year: 2023, month: 06), false) {
            viewModel.focusChanged(from: 0, to: 2)
        }
    }
}

// MARK: - 기타 정보 갱신

extension CalendarViewModelImpleTests {
    
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
            var startIndex = 1
            (0..<13).forEach { _ in
                let nextIndex = startIndex-1 < 0 ? 2 : startIndex - 1
                viewModel.focusChanged(from: startIndex, to: nextIndex)
                startIndex = nextIndex
            }
        }
        
        // then
        let currentViewingMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
            .sorted()
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
            viewModel.focusChanged(from: 1, to: 0)
            
            // 전체범위 변동 없음 => 8~11
            viewModel.focusChanged(from: 0, to: 1)
            
            // 전체 범위 => 8~12월, 신규 11~12
            viewModel.focusChanged(from: 1, to: 2)
            
            // 전체 범위 => 8~다음년도1월, 신규 12~1
            viewModel.focusChanged(from: 2, to: 0)
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
            viewModel.focusChanged(from: 1, to: 0)
            
            // 전체범위 변동 없음 => 8~11
            viewModel.focusChanged(from: 0, to: 1)
            
            // 전체 범위 => 8~12월, 신규 11~12
            viewModel.focusChanged(from: 1, to: 2)
            
            // 전체 범위 => 8~다음년도1월, 신규 12~1
            viewModel.focusChanged(from: 2, to: 0)
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

private extension CalendarViewModelImpleTests {
    
    class SpyRouter: BaseSpyRouter, CalendarViewRouting, @unchecked Sendable {
        
        var spyInteractors: [SpyPaperInteractor] = []
        var didInitialMonthsAttached: (() -> Void)?
        func attachInitialMonths(_ months: [CalendarMonth]) -> [any CalendarPaperSceneInteractor] {
            let interactors = months.map { SpyPaperInteractor(currentMonth: $0) }
            self.spyInteractors = interactors
            self.didInitialMonthsAttached?()
            return interactors
        }
    }
    
    class SpyPaperInteractor: CalendarPaperSceneInteractor, @unchecked Sendable {
        
        var currentMonth: CalendarMonth
        init(currentMonth: CalendarMonth) {
            self.currentMonth = currentMonth
        }
        
        func updateMonthIfNeed(_ newMonth: CalendarMonth) {
            self.currentMonth = newMonth
        }
        
        func monthScene(didChange currentSelectedDay: CurrentSelectDayModel, and eventsThatDay: [any CalendarEvent]) { }
    }
    
    final class SpyListener: CalendarSceneListener, @unchecked Sendable {
        
        var didMonthChanged: ((CalendarMonth, Bool) -> Void)?
        
        func calendarScene(
            focusChangedTo month: CalendarMonth,
            isCurrentMonth: Bool
        ) {
            self.didMonthChanged?(month, isCurrentMonth)
        }
    }
    
    class PrivateSpyTodoEventUsecase: StubTodoEventUsecase {
        
        var stubCurrentTodos: [TodoEvent] = []
        private let fakeCurrentTodoSubject = CurrentValueSubject<[TodoEvent], Never>([])
        override func refreshCurentTodoEvents() {
            self.fakeCurrentTodoSubject.send(stubCurrentTodos)
        }
        
        override var currentTodoEvents: AnyPublisher<[TodoEvent], Never> {
            return self.fakeCurrentTodoSubject.eraseToAnyPublisher()
        }
        
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
    
    private class PrivateSpyEventTagUsecase: StubEventTagUsecase {
        
        var didPrepared: (() -> Void)?
        override func prepare() {
            self.didPrepared?()
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
