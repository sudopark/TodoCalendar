//
//  CalendarViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/06/28.
//

import XCTest
import UIKit
import Combine
import Prelude
import Optics
import Domain
import Scenes
import TestDoubles
import UnitTestHelpKit

@testable import CalendarScenes


class CalendarViewModelImpleTests: BaseTestCase, PublisherWaitable, AsyncEffectWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var stubCalendarUsecase: StubCalendarUsecase!
    private var spyHolidayUsecase: StubHolidayUsecase!
    private var spyTodoUsecase: PrivateSpyTodoEventUsecase!
    private var spyScheduleUsecase: PrivateSpyScheduleEventUsecase!
    private var stubSettingUsecase: StubCalendarSettingUsecase!
    private var spyEventTagUsecase: PrivateSpyEventTagUsecase!
    private var spyForemostEventUsecase: StubForemostEventUsecase!
    private var stubMigrationUsecase: PrivateStubMigrationUsecase!
    private var stubUISettingUsecase: StubUISettingUsecase!
    private var spyGoogleCalednarUsecase: PrivateStubGoogleCalendarUsecase!
    private var spyAppleCalendarUsecase: PrivateStubAppleCalendarUsecase!
    private var spyListener: SpyListener!
    private var spyEventSyncUsecase: PrivateStubEventSyncUsecase!
    private var spyEventUploadService: StubEventUploadService!
    private var stubOrchestration: StubAIAgentOrchestrationUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyHolidayUsecase = .init()
        self.spyRouter = .init()
        self.spyTodoUsecase = .init()
        self.spyScheduleUsecase = .init()
        self.stubSettingUsecase = .init()
        self.spyEventTagUsecase = .init()
        self.spyForemostEventUsecase = .init(foremostId: .init("some", true))
        self.stubMigrationUsecase = .init()
        self.stubUISettingUsecase = .init()
        self.spyGoogleCalednarUsecase = .init()
        self.spyAppleCalendarUsecase = PrivateStubAppleCalendarUsecase()
        self.spyListener = .init()
        self.spyEventSyncUsecase = .init()
        self.spyEventUploadService = .init()
        self.stubOrchestration = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubCalendarUsecase = nil
        self.spyHolidayUsecase = nil
        self.spyRouter = nil
        self.spyTodoUsecase = nil
        self.spyScheduleUsecase = nil
        self.stubSettingUsecase = nil
        self.spyEventTagUsecase = nil
        self.spyForemostEventUsecase = nil
        self.stubMigrationUsecase = nil
        self.stubUISettingUsecase = nil
        self.spyGoogleCalednarUsecase = nil
        self.spyAppleCalendarUsecase = nil
        self.spyListener = nil
        self.spyEventSyncUsecase = nil
        self.spyEventUploadService = nil
        self.stubOrchestration = nil
    }
    
    private func makeViewModel(
        today: CalendarComponent.Day = .init(year: 2023, month: 02, day: 02, weekDay: 5),
        isSignedIn: Bool = true
    ) -> CalendarViewModelImple {

        let calendarUsecase = StubCalendarUsecase(today: today)
        self.stubCalendarUsecase = calendarUsecase
        let account: AccountInfo? = isSignedIn ? AccountInfo("uid") : nil

        let viewModel = CalendarViewModelImple(
            calendarUsecase: calendarUsecase,
            calendarSettingUsecase: self.stubSettingUsecase,
            holidayUsecase: self.spyHolidayUsecase,
            todoEventUsecase: self.spyTodoUsecase,
            scheduleEventUsecase: self.spyScheduleUsecase,
            foremostEventusecase: self.spyForemostEventUsecase,
            eventTagUsecase: self.spyEventTagUsecase,
            migrationUsecase: self.stubMigrationUsecase,
            uiSettingUsecase: self.stubUISettingUsecase,
            googleCalendarUsecase: self.spyGoogleCalednarUsecase,
            appleCalendarUsecase: self.spyAppleCalendarUsecase,
            eventUploadService: self.spyEventUploadService,
            eventSyncUsecase: self.spyEventSyncUsecase,
            aiAgentOrchestrationUsecase: self.stubOrchestration,
            accountUsecase: StubAccountUsecase(account)
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
        let source = self.spyHolidayUsecase.currentSelectedCountry
            .compactMap { $0 }
            .removeAllDuplicates(by: { $0.code == $1.code })
        let currentCountry = self.waitFirstOutput(expect, for: source) {
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
    
    func testViewModel_whenPrepare_refreshForemostEvent() {
        // given
        let expect = expectation(description: "prepare시에 foremostEvent 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()

        // when
        let events = self.waitOutputs(expect, for: self.spyForemostEventUsecase.foremostEvent) {
            viewModel.prepare()
        }

        // then
        let isForemostEventPrepared = events.map { $0 != nil }
        XCTAssertEqual(isForemostEventPrepared, [false, true])
    }

    func testViewModel_whenPrepare_callsOrchestrationPrepare() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.prepare()

        // then
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(self.stubOrchestration.didPrepare, true)
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
        
        parameterizeTest(expect: [
            .init(year: 2023, month: 07), .init(year: 2023, month: 08), .init(year: 2023, month: 09)
        ], { viewModel.moveFocusToToday() })
    }
    
    func testViewModel_whenFocusedMonthChanged_notify() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        viewModel.calendarPaper(on: .init(year: 2023, month: 08), didChange: .dummy(2023, 08, 02))
        func parameterizeTest(
            _ month: CalendarMonth,
            _ isCurrentYear: Bool,
            _ isCurrent: Bool,
            _ action: () -> Void
        ) {
            let expect = expectation(description: "현재 포커스된 달 조회 변경")
            var selected: SelectDayInfo?
            self.spyListener.didSelectionChanged = { info in
                selected = info
                expect.fulfill()
            }
            action()
            self.wait(for: [expect], timeout: self.timeout)
            
            XCTAssertEqual(selected?.year, month.year)
            XCTAssertEqual(selected?.month, month.month)
            XCTAssertEqual(selected?.isCurrentYear, isCurrentYear)
            XCTAssertEqual(selected?.isCurrentDay, isCurrent)
        }
        
        // when + then
        parameterizeTest(.init(year: 2023, month: 09), true, false) {
            viewModel.focusChanged(from: 1, to: 2)
            viewModel.calendarPaper(on: .init(year: 2023, month: 09), didChange: .dummy(2023, 09, 01))
        }
        parameterizeTest(.init(year: 2023, month: 10), true, false) {
            viewModel.focusChanged(from: 2, to: 0)
            viewModel.calendarPaper(on: .init(year: 2023, month: 10), didChange: .dummy(2023, 10, 01))
        }
        parameterizeTest(.init(year: 2023, month: 11), true, false) {
            viewModel.focusChanged(from: 0, to: 1)
            viewModel.calendarPaper(on: .init(year: 2023, month: 11), didChange: .dummy(2023, 11, 01))
        }
        parameterizeTest(.init(year: 2023, month: 10), true, false) {
            viewModel.focusChanged(from: 1, to: 0)
        }
        parameterizeTest(.init(year: 2023, month: 09), true, false) {
            viewModel.focusChanged(from: 0, to: 2)
        }
        parameterizeTest(.init(year: 2023, month: 08), true, true) {
            viewModel.focusChanged(from: 2, to: 1)
        }
        parameterizeTest(.init(year: 2023, month: 08), true, false) {
            viewModel.calendarPaper(
                on: .init(year: 2023, month: 08),
                didChange: .dummy(2023, 08, 03)
            )
        }
        parameterizeTest(.init(year: 2023, month: 08), true, false) {
            viewModel.calendarPaper(
                on: .init(year: 2023, month: 08),
                didChange: .dummy(2023, 08, 04)
            )
        }
        parameterizeTest(.init(year: 2023, month: 07), true, false) {
            viewModel.focusChanged(from: 1, to: 0)
            viewModel.calendarPaper(on: .init(year: 2023, month: 7), didChange: .dummy(2023, 7, 01))
        }
        parameterizeTest(.init(year: 2023, month: 06), true, false) {
            viewModel.focusChanged(from: 0, to: 2)
            viewModel.calendarPaper(on: .init(year: 2023, month: 6), didChange: .dummy(2023, 6, 01))
        }
        parameterizeTest(.init(year: 2023, month: 05), true, false) {
            viewModel.focusChanged(from: 2, to: 1)
            viewModel.calendarPaper(on: .init(year: 2023, month: 5), didChange: .dummy(2023, 5, 01))
        }
        parameterizeTest(.init(year: 2023, month: 04), true, false) {
            viewModel.focusChanged(from: 1, to: 0)
            viewModel.calendarPaper(on: .init(year: 2023, month: 04), didChange: .dummy(2023, 04, 01))
        }
        parameterizeTest(.init(year: 2023, month: 03), true, false) {
            viewModel.focusChanged(from: 0, to: 2)
            viewModel.calendarPaper(on: .init(year: 2023, month: 3), didChange: .dummy(2023, 3, 01))
        }
        parameterizeTest(.init(year: 2023, month: 02), true, false) {
            viewModel.focusChanged(from: 2, to: 1)
            viewModel.calendarPaper(on: .init(year: 2023, month: 2), didChange: .dummy(2023, 2, 01))
        }
        parameterizeTest(.init(year: 2023, month: 01), true, false) {
            viewModel.focusChanged(from: 1, to: 0)
            viewModel.calendarPaper(on: .init(year: 2023, month: 1), didChange: .dummy(2023, 1, 01))
        }
        parameterizeTest(.init(year: 2022, month: 12), false, false) {
            viewModel.focusChanged(from: 0, to: 2)
            viewModel.calendarPaper(on: .init(year: 2022, month: 12), didChange: .dummy(2022, 12, 01))
        }
    }
    
    func testViewModel_whenReturnToToday_selectCurrentMonthAndToday() {
        // given
        let expect = expectation(description: "오늘로 복귀시에 이번달 및 오늘 선택")
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        self.spyRouter.spyInteractors[1].didSelectTodayRequestedCallback = { expect.fulfill() }
        
        // when
        viewModel.focusChanged(from: 1, to: 2)
        viewModel.moveFocusToToday()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let requesteds = self.spyRouter.spyInteractors.map { $0.didSelectTodayRequested }
        XCTAssertEqual(requesteds, [nil, true, nil])
    }

    func testViewModel_whenMoveToNextMonth_slideToNextPageAndUpdateMonths() {
        // given
        let expect = expectation(description: "다음달로 슬라이드 이동")
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        self.spyRouter.didSlideFocusCallback = { [weak self] in
            self?.spyRouter.slideFocusCompletion?()
            expect.fulfill()
        }

        // when
        viewModel.moveToNextMonth()
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyRouter.didSlideFocusToIndex, 2)
        XCTAssertEqual(self.spyRouter.didSlideFocusToNext, true)
        let currentMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(currentMonths, [
            .init(year: 2023, month: 10), .init(year: 2023, month: 08), .init(year: 2023, month: 09)
        ])
    }

    func testViewModel_whenMoveToPreviousMonth_slideToPreviousPageAndUpdateMonths() {
        // given
        let expect = expectation(description: "이전달로 슬라이드 이동")
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        self.spyRouter.didSlideFocusCallback = { [weak self] in
            self?.spyRouter.slideFocusCompletion?()
            expect.fulfill()
        }

        // when
        viewModel.moveToPreviousMonth()
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyRouter.didSlideFocusToIndex, 0)
        XCTAssertEqual(self.spyRouter.didSlideFocusToNext, false)
        let currentMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(currentMonths, [
            .init(year: 2023, month: 07), .init(year: 2023, month: 08), .init(year: 2023, month: 06)
        ])
    }

    func testViewModel_whenMoveToPreviousMonthTwice_slideAcrossPageBoundary() {
        // given
        let expect = expectation(description: "페이지 경계를 넘어 연속 이동")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        self.spyRouter.didSlideFocusCallback = { [weak self] in
            self?.spyRouter.slideFocusCompletion?()
            expect.fulfill()
        }

        // when
        viewModel.moveToPreviousMonth()
        viewModel.moveToPreviousMonth()
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyRouter.didSlideFocusToIndex, 2)
        XCTAssertEqual(self.spyRouter.didSlideFocusToNext, false)
        let currentMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(currentMonths, [
            .init(year: 2023, month: 07), .init(year: 2023, month: 05), .init(year: 2023, month: 06)
        ])
    }

    func testViewModel_whenTodayRequestedDuringSlideAnimation_staleSlideCompletionDoesNotOverwriteFocus() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        let slideRequested = expectation(description: "슬라이드 요청 도착 대기")
        self.spyRouter.didSlideFocusCallback = { slideRequested.fulfill() }
        viewModel.moveToNextMonth()
        self.wait(for: [slideRequested], timeout: self.timeout)

        // when
        let todayApplied = expectation(description: "애니메이션 진행 중 TODAY 복귀 완료 대기")
        self.spyRouter.spyInteractors[1].didSelectTodayRequestedCallback = { todayApplied.fulfill() }
        viewModel.moveFocusToToday()
        self.wait(for: [todayApplied], timeout: self.timeout)
        // 슬라이드 애니메이션 완료 콜백이 TODAY 복귀보다 늦게 도착
        self.spyRouter.slideFocusCompletion?()

        // then
        let currentMonths = self.spyRouter.spyInteractors.map { $0.currentMonth }
        XCTAssertEqual(currentMonths, [
            .init(year: 2023, month: 07), .init(year: 2023, month: 08), .init(year: 2023, month: 09)
        ])
        XCTAssertEqual(self.spyRouter.spyInteractors[1].didSelectTodayRequested, true)
    }

    func testViewModel_moveDay() {
        // given
        let expect = expectation(description: "특정 일자로 이동")
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 08, day: 02, weekDay: 3)
        )
        self.spyRouter.spyInteractors[1].didSelectDayCallback = { expect.fulfill() }
        
        // when
        viewModel.moveDay(.init(2024, 04, 03))
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let requested = self.spyRouter.spyInteractors.map {
            $0.didSelectDay
        }
        XCTAssertEqual(requested, [
            nil, .init(2024, 04, 03), nil
        ])
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
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 04, weekDay: 3)
        )
        
        // when
        let totalRange = self.range((2023, 01, 01), (2025, 01, 01))
        let source = self.spyTodoUsecase.todoEvents(in: totalRange)
        let todoLists = self.waitOutputs(expect, for: source) {
            // 전체 범위 => 9~11월 신규 => 2023년
            
            // 전체 범위 => 8~11월, 신규 x
            viewModel.focusChanged(from: 1, to: 0)
            
            // 전체범위 변동 없음 => 8~11
            viewModel.focusChanged(from: 0, to: 1)
            
            // 전체 범위 => 8~12월, 신규 x
            viewModel.focusChanged(from: 1, to: 2)
            
            // 전체 범위 => 8~다음년도1월, 신규 => 2024년
            viewModel.focusChanged(from: 2, to: 0)
        }
        
        // then
        let todoIdLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(todoIdLists, [
            ["kst-month: 2023.01.01_00:00..<2024.01.01_00:00"],
            ["kst-month: 2023.01.01_00:00..<2024.01.01_00:00", "kst-month: 2024.01.01_00:00..<2025.01.01_00:00"]
        ])
    }
    
    func testViewModel_whenRangeChangeAndNewMonthAppened_reloadScheduleEventsInTotalPeriod() {
        // given
        let expect = expectation(description: "calendar가 조회중인 전체 조회 기간이 길어지면 시간정보 있는 할일 이벤트 다시 조회")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 04, weekDay: 3)
        )
        
        // when
        let totalRange = self.range((2023, 01, 01), (2025, 01, 01))
        let source = self.spyScheduleUsecase.scheduleEvents(in: totalRange)
        let scheduleLists = self.waitOutputs(expect, for: source) {
            // 전체 범위 => 9~11월, 신규 => 2023년
            
            // 전체 범위 => 8~11월, 신규 x
            viewModel.focusChanged(from: 1, to: 0)
            
            // 전체범위 변동 없음 => 8~11
            viewModel.focusChanged(from: 0, to: 1)
            
            // 전체 범위 => 8~12월, 신규 x
            viewModel.focusChanged(from: 1, to: 2)
            
            // 전체 범위 => 8~다음년도1월, 신규 => 2024년
            viewModel.focusChanged(from: 2, to: 0)
        }
        
        // then
        let scheduleIdLists = scheduleLists.map { ss in ss.map { $0.uuid } }
        XCTAssertEqual(scheduleIdLists, [
            ["kst-month: 2023.01.01_00:00..<2024.01.01_00:00"],
            ["kst-month: 2023.01.01_00:00..<2024.01.01_00:00", "kst-month: 2024.01.01_00:00..<2025.01.01_00:00"]
        ])
    }
    
    func testViewModel_whenRefreshEvents_requestRefreshGoogleCalendarEvent() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 04, weekDay: 3)
        )

        // when
        // 전체 범위 => 8~11월, 신규 x
        viewModel.focusChanged(from: 1, to: 0)
        
        // 전체범위 변동 없음 => 8~11
        viewModel.focusChanged(from: 0, to: 1)
        
        // 전체 범위 => 8~12월, 신규 x
        viewModel.focusChanged(from: 1, to: 2)
        
        // 전체 범위 => 8~다음년도1월, 신규 => 2024년
        viewModel.focusChanged(from: 2, to: 0)
        
        // then
        XCTAssertEqual(self.spyGoogleCalednarUsecase.didRefreshedPeriod, [
            "2023.01.01_00:00..<2024.01.01_00:00",
            "2024.01.01_00:00..<2025.01.01_00:00"
        ])
    }
    
    func testViewModel_whenAfterGoogleCalendarIntegrated_refreshEventsAllCheckedRanges() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 04, weekDay: 3)
        )

        // when
        // 전체 범위 => 8~11월, 신규 x
        viewModel.focusChanged(from: 1, to: 0)

        // 전체범위 변동 없음 => 8~11
        viewModel.focusChanged(from: 0, to: 1)

        // 전체 범위 => 8~12월, 신규 x
        viewModel.focusChanged(from: 1, to: 2)

        // 전체 범위 => 8~다음년도1월, 신규 => 2024년
        viewModel.focusChanged(from: 2, to: 0)

        // then
        XCTAssertEqual(self.spyGoogleCalednarUsecase.didRefreshedPeriod, [
            "2023.01.01_00:00..<2024.01.01_00:00",
            "2024.01.01_00:00..<2025.01.01_00:00"
        ])
    }

    func testViewModel_whenAfterFocusChanged_refreshAppleCalendarEvents() {
        // given
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 04, weekDay: 3)
        )

        // when - 새 연도 범위 진입
        viewModel.focusChanged(from: 1, to: 0)
        viewModel.focusChanged(from: 0, to: 1)
        viewModel.focusChanged(from: 1, to: 2)
        viewModel.focusChanged(from: 2, to: 0)

        // then - Apple Calendar도 동일하게 갱신됨
        XCTAssertEqual(self.spyAppleCalendarUsecase.didRefreshedPeriod, [
            "2023.01.01_00:00..<2024.01.01_00:00",
            "2024.01.01_00:00..<2025.01.01_00:00"
        ])
    }
    
    // timeZone 변경시도 테스트 추가해야함
    func testViewModel_whenTimeZoneChanged_refreshNotCheckedRange() {
        // given
        let expect = expectation(description: "timeZone 변경시에 새로운 구간에 대한 todo 이벤트 조회")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 11, day: 4, weekDay: 2)
        )
        
        // when
        let totalRange = self.range((2023, 01, 01), (2025, 01, 01))
        let source = self.spyTodoUsecase.todoEvents(in: totalRange)
        let todoLists = self.waitOutputs(expect, for: source) {
            // 최초 9~11월 나몸
            
            // timeZone pdt로 변경 => 현재보다 16+1시간 만큼 미래시간으로 지정됨(1월 1일 기준 pst로 계산됨)
            // 달력의 마지막날인 2023-12-31일 23:59:59에서 pdt로 빼낸 interval을 kst로 변경하면 1월 1일임
            // kst 기준 계산된 2023년도의 범위가 -> pdt 기준으로 변경되고, upper bound가 16+1시간 만큼 증가
            self.stubSettingUsecase.selectTimeZone(TimeZone(abbreviation: "PDT")!)
        }
        
        // then
        let todoIdLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(todoIdLists, [
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00"
            ],
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00",
                "kst-month: 2024.01.01_00:00..<2024.01.01_17:00"
            ],
        ])
    }
    
    private func parameterizeTestRefreshTodo(
        _ actionName: String, _ action: @escaping () -> Void
    ) {
        // given
        let expect = expectation(description: "\(actionName) 시에 조회중인 범위의 todo 이벤트 다시 조회")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 4, weekDay: 3)
        )
        
        // when
        let totalRange = self.range((2023, 01, 01), (2025, 01, 01))
        let source = self.spyTodoUsecase.todoEvents(in: totalRange)
        let todoLists = self.waitOutputs(expect, for: source) {
            action()
        }
        // then
        let todoIdLists = todoLists.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(todoIdLists, [
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00"
            ],
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00",
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00"
            ]
        ])
    }
    
    func testViewModel_whenEnterForeground_refreshTodoEvents() {
        // given
        // when + then
        self.parameterizeTestRefreshTodo("포그라운드 복귀") {
            NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))
        }
    }
    
    func testViewModel_whenDataSyncEnd_refreshTodoEvents() {
        // given
        // when + then
        self.parameterizeTestRefreshTodo("event sync 완료") {
            self.spyEventSyncUsecase.updateIsSync(true)
            self.spyEventSyncUsecase.updateIsSync(false)
        }
    }
    
    private func parameterizeTestRefreshSchedule(
        _ actionName: String, _ action: @escaping () -> Void
    ) {
        // given
        let expect = expectation(description: "\(actionName)시에 조회중인 범위의 schedule 이벤트 다시 조회")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 4, weekDay: 3)
        )
        
        // when
        let totalRange = self.range((2023, 01, 01), (2025, 01, 01))
        let source = self.spyScheduleUsecase.scheduleEvents(in: totalRange)
        let scheduleLists = self.waitOutputs(expect, for: source) {
            action()
        }
        // then
        let scheduleIdLists = scheduleLists.map { ss in ss.map { $0.uuid } }
        XCTAssertEqual(scheduleIdLists, [
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00"
            ],
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00",
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00"
            ]
        ])
    }
    
    func testViewModel_whenEnterForeground_refreshScheduleEvents() {
        // given
        // when + then
        self.parameterizeTestRefreshSchedule("포그라운드 복귀") {
            NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))
        }
    }
    
    func testViewModel_whenEventSyncEnd_refreshScheduleEvents() {
        // given
        // when + then
        self.parameterizeTestRefreshSchedule("event sync 완료") {
            self.spyEventSyncUsecase.updateIsSync(true)
            self.spyEventSyncUsecase.updateIsSync(false)
        }
    }
    
    private func parameterizeTestRefreshCurrentTodo(
        _ actionName: String, _ action: @escaping () -> Void
    ) {
        // given
        let expect = expectation(description: "\(actionName) 시에 조회중인 범위의 current todo 이벤트 다시 조회")
        expect.expectedFulfillmentCount = 2
        self.spyTodoUsecase.stubCurrentTodos = [TodoEvent(uuid: "current", name: "some")]
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 4, weekDay: 3)
        )
        
        // when
        let source = self.spyTodoUsecase.currentTodoEvents
        let currentTodos = self.waitOutputs(expect, for: source) {
            action()
        }
        
        // then
        let ids = currentTodos.map { ts in ts.map { $0.uuid } }
        XCTAssertEqual(ids, [
            ["current"], ["current"]
        ])
    }
    
    func testViewModel_whenEnterForeground_refreshCurrentTodos() {
        // given
        // when + then
        self.parameterizeTestRefreshCurrentTodo("포그라운드 복귀") {
            NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))
        }
    }
    
    func testViewModel_whenEventSyncEnd_refreshCurrentTodos() {
        // given
        // when + then
        self.parameterizeTestRefreshCurrentTodo("event sync 완료") {
            self.spyEventSyncUsecase.updateIsSync(true)
            self.spyEventSyncUsecase.updateIsSync(false)
        }
    }
    
    func testViewModel_whenAfterMigration_refreshEvents() {
        // given
        let expect = expectation(description: "migration 완료 이후 조회중인 범위의 이벤트 다시 조회")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialSetup(
            .init(year: 2023, month: 10, day: 4, weekDay: 3)
        )
        
        // when
        let totalRange = self.range((2023, 01, 01), (2025, 01, 01))
        let source = self.spyScheduleUsecase.scheduleEvents(in: totalRange)
        let scheduleLists = self.waitOutputs(expect, for: source) {
            self.stubMigrationUsecase.migrationEndMocking.send(.success(()))
        }
        // then
        let scheduleIdLists = scheduleLists.map { ss in ss.map { $0.uuid } }
        XCTAssertEqual(scheduleIdLists, [
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00"
            ],
            [
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00",
                "kst-month: 2023.01.01_00:00..<2024.01.01_00:00"
            ]
        ])
    }
}

// MARK: - refresh uncompleted todos

extension CalendarViewModelImpleTests {
    
    private func makeViewModelWithShowUncompletedTodo(show: Bool) -> CalendarViewModelImple {
        _ = try? self.stubUISettingUsecase.changeCalendarAppearanceSetting(
            .init() |> \.showUncompletedTodos .~ show
        )
        return self.makeViewModel()
    }
    
    func testViewModel_whenPrepare_refreshUncompletedTodos() {
        // given
        let expect = expectation(description: "prepare시에 완료되지 않은 할일 조회")
        let viewModel = self.makeViewModelWithShowUncompletedTodo(show: true)
        self.spyTodoUsecase.didRefreshUncompletedTodoCalledCallback = {
            expect.fulfill()
        }
        
        // when
        viewModel.prepare()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    // prepare시에 완료되지않은 할일 노출 옵션 꺼진 경우 조회 안함
    func testViewModel_whenPrepareAndShowUncompletedTodoOptionIsOff_notRefresh() {
        // given
        let expect = expectation(description: "prepare시에 완료되지않은 할일 노출 옵션 꺼진 경우 조회 안함")
        expect.isInverted = true
        let viewModel = self.makeViewModelWithShowUncompletedTodo(show: false)
        
        // when
        self.spyTodoUsecase.didRefreshUncompletedTodoCalledCallback = {
            expect.fulfill()
        }
        viewModel.prepare()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    // 완료되지않은 할일 옵션이 off -> on 으로 변경된 경우 할일 조회
    func testViewModel_whenShowUncompletedTodoOptionChangedToOn_refresh() {
        // given
        let expect = expectation(description: "완료되지않은 할일 노출 옵션이 off -> on으로 변경된경우 refresh")
        let viewModel = self.makeViewModelWithShowUncompletedTodo(show: false)
        viewModel.prepare()
        
        // when
        self.spyTodoUsecase.didRefreshUncompletedTodoCalledCallback = {
            expect.fulfill()
        }
        _ = try? self.stubUISettingUsecase.changeCalendarAppearanceSetting(
            .init() |> \.showUncompletedTodos .~ true
        )
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_whenEnterForegroundOrDateChaned_refresh() {
        // given
        let expect = expectation(description: "포그라운드 복귀하거나, 날짜 변경된 경우 refresh")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithShowUncompletedTodo(show: true)
        viewModel.prepare()
        
        // when
        self.spyTodoUsecase.didRefreshUncompletedTodoCalledCallback = {
            expect.fulfill()
        }
        NotificationCenter.default.post(
            Notification(name: UIApplication.willEnterForegroundNotification)
        )
        self.stubCalendarUsecase.makeFakeDayChanedEvent(
            .init(year: 2023, month: 03, day: 04, weekDay: 3)
        )
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_whenEventSyncEnd_refreshUncompletedTodo() {
        // given
        let expect = expectation(description: "이벤트 싱크 완료 이후에 완료되지 않은 할일 목록 갱신")
        let viewModel = self.makeViewModelWithShowUncompletedTodo(show: true)
        viewModel.prepare()
        
        // when
        self.spyTodoUsecase.didRefreshUncompletedTodoCalledCallback = {
            expect.fulfill()
        }
        self.spyEventSyncUsecase.updateIsSync(true)
        self.spyEventSyncUsecase.updateIsSync(false)
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
}

// MARK: - evnet sync and upload

extension CalendarViewModelImpleTests {
    
    func testViewModel_whenPrepare_syncEvents() async throws {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.prepare()
        
        // then
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(self.spyEventSyncUsecase.didSyncRequestedCount, 1)
    }
    
    func testViewModel_whenEnterForeground_syncEvents() async throws {
        // given
        let viewModel = self.makeViewModel()
        viewModel.prepare()
        
        // when
        NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))
        
        // then
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(self.spyEventSyncUsecase.didSyncRequestedCount, 2)
    }
    
    func testViewModel_whenPrepare_resumeEventUpload() async throws {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.prepare()
        
        // then
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(self.spyEventUploadService.isResumeOrPauses, [true])
    }
    
    func testViewModel_whenEnterBackgroundAndForeground_pauseAndResumeEventUploadService() async throws {
        // given
        let viewModel = self.makeViewModel()
        viewModel.prepare()
        
        // when
        try await Task.sleep(for: .milliseconds(10))
        NotificationCenter.default.post(Notification(name: UIApplication.didEnterBackgroundNotification))
        
        try await Task.sleep(for: .milliseconds(10))
        NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))

        // then
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(self.spyEventUploadService.isResumeOrPauses, [true, false, true])
    }
}


// MARK: - AI command 결과 시트 자동 present (단일 인스턴스 책임)

extension CalendarViewModelImpleTests {

    func testViewModel_whenAIEntersCommandPhase_routesToAICommand() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.prepare()

        // when
        self.stubOrchestration.stateSubject.send(.idle)
        self.stubOrchestration.stateSubject.send(.processing(command: "회의"))

        // then
        XCTAssertEqual(self.spyRouter.didRouteToAICommandCount, 1)
    }

    func testViewModel_whenStayInCommandPhase_routesOnlyOncePerEntry() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.prepare()

        // when — command phase 진입 후 같은 phase 내 전이
        self.stubOrchestration.stateSubject.send(.processing(command: "회의"))
        self.stubOrchestration.stateSubject.send(.done(command: "회의", message: "완료"))

        // then — 진입 edge에서만 1회
        XCTAssertEqual(self.spyRouter.didRouteToAICommandCount, 1)
    }

    func testViewModel_whenDayEventListRequestsShowCommand_routesToAICommand() {
        // given
        let viewModel = self.makeViewModel()

        // when — 하위 DayEventList 진입 버튼 재진입을 위임받음
        viewModel.calendarPaperDidRequestShowAICommand()

        // then
        XCTAssertEqual(self.spyRouter.didRouteToAICommandCount, 1)
    }

    // AI 커맨드 시트가 paywall 요청을 되돌려 보낼 대상은 자기 자신(AIAgentCommandSceneListener)이어야 한다
    func testViewModel_whenRoutingToAICommand_passesSelfAsListener() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.calendarPaperDidRequestShowAICommand()

        // then
        XCTAssertTrue(self.spyRouter.didRouteToAICommandListener === viewModel)
    }
}

// MARK: - 한도 초과 시트 → paywall 진입 위임 (#887)

extension CalendarViewModelImpleTests {

    func testViewModel_whenAIAgentCommandRequestsPaywall_routesToPaywall() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.aiAgentCommandDidRequestPaywall()

        // then
        XCTAssertEqual(self.spyRouter.didRouteToPaywallCount, 1)
    }
}

// MARK: - 음성 입력 진입 시 포커스된 달만 스크롤

extension CalendarViewModelImpleTests {

    func testViewModel_whenVoiceInputStarts_scrollsOnlyFocusedMonthPaper() async throws {
        // given
        let viewModel = self.makeViewModel()
        try await self.prepareInitialMonths(viewModel)

        // when
        self.stubOrchestration.stateSubject.send(.listening(.voice))

        // then — 초기 포커스는 가운데(index 1) 달
        try await self.assertScrollToVoiceInputCounts([0, 1, 0])
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenFocusMovedToOtherMonth_scrollsThatMonthPaper() async throws {
        // given
        let viewModel = self.makeViewModel()
        try await self.prepareInitialMonths(viewModel)

        // when
        viewModel.focusChanged(from: 1, to: 2)
        self.stubOrchestration.stateSubject.send(.listening(.voice))

        // then
        try await self.assertScrollToVoiceInputCounts([0, 0, 1])
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenStayInVoiceListening_scrollsOnlyOncePerEntry() async throws {
        // given
        let viewModel = self.makeViewModel()
        try await self.prepareInitialMonths(viewModel)

        // when — 같은 상태가 반복 방출돼도 진입 edge는 1회
        self.stubOrchestration.stateSubject.send(.listening(.voice))
        self.stubOrchestration.stateSubject.send(.listening(.voice))

        // then
        try await self.assertScrollToVoiceInputCounts([0, 1, 0])
        withExtendedLifetime(viewModel) { }
    }

    private var scrollToVoiceInputCounts: [Int] {
        return self.spyRouter.spyInteractors.map { $0.didScrollToVoiceInputCount }
    }

    // 스크롤이 도착할 때까지 기다린 뒤, 뒤늦은 추가 방출이 없는지 정착 시간을 두고 다시 본다
    private func assertScrollToVoiceInputCounts(_ expected: [Int]) async throws {
        try await self.waitEffect("스크롤 횟수 \(expected) 도달") { self.scrollToVoiceInputCounts == expected }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(self.scrollToVoiceInputCounts, expected)
    }
}

// MARK: - 외부 진입점의 AI 입력 요청 (requestAIEntry)

extension CalendarViewModelImpleTests {

    // prepare() → prepareInitialMonths의 Task가 monthsInCurrentRange를 채울 때까지 대기.
    // didInitialMonthsAttached는 send 직전에 불려 한 틱 양보가 필요하다.
    private func prepareInitialMonths(_ viewModel: CalendarViewModelImple) async throws {
        let expect = expectation(description: "초기 월 구성 완료 대기")
        self.spyRouter.didInitialMonthsAttached = { expect.fulfill() }
        viewModel.prepare()
        await self.fulfillment(of: [expect], timeout: self.timeout)
        self.spyRouter.didInitialMonthsAttached = nil
        try await Task.sleep(for: .milliseconds(10))
    }

    func testViewModel_whenRequestAIEntryOnCommandPhase_routeToAICommand() async throws {
        // given
        let viewModel = self.makeViewModel()
        self.stubOrchestration.stateSubject.send(.processing(command: "회의"))
        try await self.prepareInitialMonths(viewModel)

        // when
        viewModel.requestAIEntry()

        // then — command phase 진입으로 자동 표시가 1회, 진입 요청이 1회
        XCTAssertEqual(self.spyRouter.didRouteToAICommandCount, 2)
        XCTAssertNil(self.stubOrchestration.didEnterVoiceInput)
        XCTAssertNil(self.spyRouter.didShowConfirmWith)
    }

    func testViewModel_whenRequestAIEntryOnIdleAndSignedIn_enterVoiceInput() async throws {
        // given
        let viewModel = self.makeViewModel(isSignedIn: true)
        self.stubOrchestration.stateSubject.send(.idle)
        try await self.prepareInitialMonths(viewModel)

        // when
        viewModel.requestAIEntry()

        // then
        XCTAssertEqual(self.stubOrchestration.didEnterVoiceInput, true)
        XCTAssertEqual(self.spyRouter.didRouteToAICommandCount, 0)
        XCTAssertNil(self.spyRouter.didShowConfirmWith)
    }

    func testViewModel_whenRequestAIEntryWithoutSignIn_askSignIn() async throws {
        // given
        let viewModel = self.makeViewModel(isSignedIn: false)
        self.stubOrchestration.stateSubject.send(.idle)
        try await self.prepareInitialMonths(viewModel)

        // when
        viewModel.requestAIEntry()

        // then
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
        XCTAssertNil(self.stubOrchestration.didEnterVoiceInput)
        // SpyRouter.showConfirm은 기본적으로 confirmed?()를 즉시 실행
        XCTAssertEqual(self.spyRouter.didRouteToSignIn, true)
    }

    func testViewModel_whenRequestAIEntryBeforeAIStateEmitted_notEnterVoiceInput() async throws {
        // given
        let viewModel = self.makeViewModel(isSignedIn: true)
        try await self.prepareInitialMonths(viewModel)

        // when
        viewModel.requestAIEntry()
        try await Task.sleep(for: .milliseconds(10))

        // then
        XCTAssertNil(self.stubOrchestration.didEnterVoiceInput)
        XCTAssertEqual(self.spyRouter.didRouteToAICommandCount, 0)
    }

    func testViewModel_whenAIStateEmittedAfterRequestAIEntry_enterVoiceInput() async throws {
        // given
        let viewModel = self.makeViewModel(isSignedIn: true)
        try await self.prepareInitialMonths(viewModel)
        viewModel.requestAIEntry()

        // when
        self.stubOrchestration.stateSubject.send(.idle)
        try await Task.sleep(for: .milliseconds(10))

        // then
        XCTAssertEqual(self.stubOrchestration.didEnterVoiceInput, true)
    }

    func testViewModel_whenProcessingStateEmittedAfterRequestAIEntry_routeToAICommand() async throws {
        // given
        let viewModel = self.makeViewModel(isSignedIn: true)
        try await self.prepareInitialMonths(viewModel)
        viewModel.requestAIEntry()

        // when
        self.stubOrchestration.stateSubject.send(.processing(command: "회의"))
        try await Task.sleep(for: .milliseconds(10))

        // then — command phase 진입으로 자동 표시가 1회, 대기하던 진입 요청이 1회
        XCTAssertEqual(self.spyRouter.didRouteToAICommandCount, 2)
        XCTAssertNil(self.stubOrchestration.didEnterVoiceInput)
    }

    func testViewModel_whenRequestAIEntryBeforeCalendarAttached_notEnterVoiceInput() async throws {
        // given
        let viewModel = self.makeViewModel(isSignedIn: true)
        self.stubOrchestration.stateSubject.send(.idle)

        // when
        viewModel.requestAIEntry()
        try await Task.sleep(for: .milliseconds(10))

        // then
        XCTAssertNil(self.stubOrchestration.didEnterVoiceInput)
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
        
        var didChangedFocusIndex: Int?
        func changeFocus(at index: Int) {
            self.didChangedFocusIndex = index
        }

        var didSlideFocusToIndex: Int?
        var didSlideFocusToNext: Bool?
        var didSlideFocusCallback: (() -> Void)?
        var slideFocusCompletion: (() -> Void)?
        func slideFocus(to index: Int, isNext: Bool, completed: @escaping @Sendable () -> Void) {
            self.didSlideFocusToIndex = index
            self.didSlideFocusToNext = isNext
            self.slideFocusCompletion = completed
            self.didSlideFocusCallback?()
        }

        var didRouteToAICommandCount: Int = 0
        var didRouteToAICommandListener: (any AIAgentCommandSceneListener)?
        func routeToAICommand(listener: (any AIAgentCommandSceneListener)?) {
            self.didRouteToAICommandCount += 1
            self.didRouteToAICommandListener = listener
        }

        var didRouteToPaywallCount: Int = 0
        func routeToPaywall() {
            self.didRouteToPaywallCount += 1
        }

        var didRouteToSignIn: Bool?
        func routeToSignIn() {
            self.didRouteToSignIn = true
        }

        var didOpenSystemSetting: Bool?
        func openSystemSetting() {
            self.didOpenSystemSetting = true
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
        
        var didSelectTodayRequested: Bool?
        var didSelectTodayRequestedCallback: (() -> Void)?
        func selectToday() {
            self.didSelectTodayRequested = true
            self.didSelectTodayRequestedCallback?()
        }
        
        var didSelectDay: CalendarDay?
        var didSelectDayCallback: (() -> Void)?
        func selectDay(_ day: CalendarDay) {
            self.didSelectDay = day
            self.didSelectDayCallback?()
        }
        
        var didScrollToVoiceInputCount: Int = 0
        func scrollToVoiceInput() {
            self.didScrollToVoiceInputCount += 1
        }

        func monthScene(didChange currentSelectedDay: CurrentSelectDayModel, and eventsThatDay: [any CalendarEvent]) { }
        func monthScene(didRequestShare range: Range<TimeInterval>, kind: CalendarShareRangeKind) { }
        func dayEventListDidRequestShowAICommand() { }
    }
    
    final class SpyListener: CalendarSceneListener, @unchecked Sendable {
        
        var didSelectionChanged: ((SelectDayInfo) -> Void)?
        
        func calendarScene(focusChangedTo selected: SelectDayInfo) {
            self.didSelectionChanged?(selected)
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
            
            let dateText: (Date) -> String = {
                let formatter = DateFormatter() 
                    |> \.dateFormat .~ "yyyy.MM.dd_HH:mm"
                    |> \.timeZone .~ TimeZone(abbreviation: "KST")
                return formatter.string(from: $0)
            }
            
            let start = period.lowerBound |> Date.init(timeIntervalSince1970:) |> dateText
            let end = period.upperBound |> Date.init(timeIntervalSince1970:) |> dateText
            
            let newTodo = TodoEvent(uuid: "kst-month: \(start)..<\(end)", name: "dummy")
                |> \.time .~ EventTime.at(period.lowerBound)
            let newTodos = (self.todoEventsInRange.value ?? []) <> [newTodo]
            self.todoEventsInRange.send(newTodos)
        }
        
        override func todoEvents(in period: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], Never> {
            return self.todoEventsInRange
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }
        
        var didRefreshUncompletedTodoCalledCallback: (() -> Void)?
        override func refreshUncompletedTodos() {
            self.didRefreshUncompletedTodoCalledCallback?()
        }
    }
    
    private class PrivateSpyEventTagUsecase: StubEventTagUsecase, @unchecked Sendable {
        
        var didPrepared: (() -> Void)?
        override func prepare() {
            self.didPrepared?()
        }
    }
    
    class PrivateSpyScheduleEventUsecase: StubScheduleEventUsecase, @unchecked Sendable {
        
        private let scheduleEventsInRange = CurrentValueSubject<[ScheduleEvent]?, Never>(nil)
        override func refreshScheduleEvents(in period: Range<TimeInterval>) {
            let dateText: (Date) -> String = {
                let formatter = DateFormatter()
                    |> \.dateFormat .~ "yyyy.MM.dd_HH:mm"
                    |> \.timeZone .~ TimeZone(abbreviation: "KST")
                return formatter.string(from: $0)
            }
            
            let start = period.lowerBound |> Date.init(timeIntervalSince1970:) |> dateText
            let end = period.upperBound |> Date.init(timeIntervalSince1970:) |> dateText
            
            let newOne = ScheduleEvent(
                uuid: "kst-month: \(start)..<\(end)",
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
    
    final class PrivateStubGoogleCalendarUsecase: StubGoogleCalendarUsecase, @unchecked Sendable {
        
        var didRefreshedPeriod: [String] = []
        override func refreshEvents(in period: Range<TimeInterval>) {
            let dateText: (Date) -> String = {
                let formatter = DateFormatter()
                    |> \.dateFormat .~ "yyyy.MM.dd_HH:mm"
                    |> \.timeZone .~ TimeZone(abbreviation: "KST")
                return formatter.string(from: $0)
            }
            
            let start = period.lowerBound |> Date.init(timeIntervalSince1970:) |> dateText
            let end = period.upperBound |> Date.init(timeIntervalSince1970:) |> dateText
            let periodText = "\(start)..<\(end)"
            self.didRefreshedPeriod.append(periodText)
        }
    }
    
    final class PrivateStubAppleCalendarUsecase: StubAppleCalendarUsecase, @unchecked Sendable {

        var didRefreshedPeriod: [String] = []
        override func refreshEvents(in period: Range<TimeInterval>) {
            let dateText: (Date) -> String = {
                let formatter = DateFormatter()
                    |> \.dateFormat .~ "yyyy.MM.dd_HH:mm"
                    |> \.timeZone .~ TimeZone(abbreviation: "KST")
                return formatter.string(from: $0)
            }

            let start = period.lowerBound |> Date.init(timeIntervalSince1970:) |> dateText
            let end = period.upperBound |> Date.init(timeIntervalSince1970:) |> dateText
            let periodText = "\(start)..<\(end)"
            self.didRefreshedPeriod.append(periodText)
        }
    }

    private class PrivateStubMigrationUsecase: StubTemporaryUserDataMigrationUescase, @unchecked Sendable {
        
        let migrationEndMocking = PassthroughSubject<Result<Void, any Error>, Never>()
        
        override var migrationResult: AnyPublisher<Result<Void, any Error>, Never> {
            return self.migrationEndMocking
                .eraseToAnyPublisher()
        }
    }
    
    private class PrivateStubEventSyncUsecase: StubEventSyncUsecase, @unchecked Sendable {

        private let isSyncing = CurrentValueSubject<EventSyncStatus, Never>(.idle)
        func updateIsSync(_ isSync: Bool) {
            self.isSyncing.send(isSync ? .incrementalSyncing : .idle)
        }

        override var syncStatus: AnyPublisher<EventSyncStatus, Never> {
            return isSyncing.removeDuplicates()
                .eraseToAnyPublisher()
        }
    }
}

// MARK: - 앱 백그라운드 전환과 음성 입력

extension CalendarViewModelImpleTests {

    // VM이 해제되면 구독도 끊겨 단언이 무의미해지므로 호출측이 받아 살려둔다
    private func postAppLifecycleAfterPrepared(
        _ notificationName: Notification.Name,
        state: AIAgentState?
    ) async throws -> CalendarViewModelImple {
        let viewModel = self.makeViewModel()
        try await self.prepareInitialMonths(viewModel)
        state.map { self.stubOrchestration.stateSubject.send($0) }

        NotificationCenter.default.post(name: notificationName, object: nil)
        return viewModel
    }

    private func enterBackgroundAfterPrepared(state: AIAgentState?) async throws -> CalendarViewModelImple {
        return try await self.postAppLifecycleAfterPrepared(
            UIApplication.didEnterBackgroundNotification, state: state
        )
    }

    // 중지가 일어나지 '않음'을 보는 케이스는 기다릴 조건이 없어 정착 시간만 둔다
    private func assertKeepsInputAfterSettling() async throws {
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(self.stubOrchestration.didStopInput)
    }

    func testViewModel_whenAppEntersBackgroundWhileVoiceListening_stopsInput() async throws {
        // given, when
        let viewModel = try await self.enterBackgroundAfterPrepared(state: .listening(.voice))

        // then
        try await self.waitEffect("백그라운드 전환으로 입력 중지") { self.stubOrchestration.didStopInput == true }
        XCTAssertEqual(self.stubOrchestration.didStopInput, true)
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenAppEntersBackgroundWhileKeyboardListening_keepsInput() async throws {
        // given, when
        let viewModel = try await self.enterBackgroundAfterPrepared(state: .listening(.keyboard))

        // then
        try await self.assertKeepsInputAfterSettling()
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenAppEntersBackgroundWhileIdle_keepsInput() async throws {
        // given, when
        let viewModel = try await self.enterBackgroundAfterPrepared(state: .idle)

        // then
        try await self.assertKeepsInputAfterSettling()
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenAppResignsActiveWhileVoiceListening_keepsInput() async throws {
        // given, when
        let viewModel = try await self.postAppLifecycleAfterPrepared(
            UIApplication.willResignActiveNotification, state: .listening(.voice)
        )

        // then
        try await self.assertKeepsInputAfterSettling()
        withExtendedLifetime(viewModel) { }
    }

    private func makePreparedViewModel() async throws -> CalendarViewModelImple {
        let viewModel = self.makeViewModel()
        try await self.prepareInitialMonths(viewModel)
        return viewModel
    }

    func testViewModel_whenSpeechPermissionDenied_showsSettingGuide() async throws {
        // given
        let viewModel = try await self.makePreparedViewModel()

        // when
        self.stubOrchestration.speechPermissionDeniedSubject.send(())
        try await Task.sleep(for: .milliseconds(50))

        // then
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
        XCTAssertEqual(self.spyRouter.didOpenSystemSetting, true)
        withExtendedLifetime(viewModel) { }
    }
}

private extension CurrentSelectDayModel {
    
    static func dummy(_ year: Int, _ month: Int, _ day: Int) -> Self {
        return .init(year, month, day, weekId: "some", range: 0..<1)
    }
}
