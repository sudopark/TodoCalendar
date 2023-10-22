//
//  DayEventListViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/09/03.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes


class DayEventListViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubTodoUsecase: StubTodoEventUsecase!
    private var stubTagUsecase: StubEventTagUsecase!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubTodoUsecase = .init()
        self.stubTagUsecase = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubTodoUsecase = nil
        self.stubTagUsecase = nil
        self.spyRouter = nil
    }
    
    // 9-10일: current-todo-1, current-todo-2, todo-with-time, not-repeating-schedule, repeating-schedule(turn 4)
    // 9-11일: current-todo-1, current-todo-2
    private func makeViewModel(
        shouldFailDoneTodo: Bool = false,
        shouldFailMakeTodo: Bool = false
    ) -> DayEventListViewModelImple {
        let currentTodos: [TodoEvent] = [
            .init(uuid: "current-todo-1", name: "current-todo-1"),
            .init(uuid: "current-todo-2", name: "current-todo-2")
        ]

        self.stubTodoUsecase.stubCurrentTodoEvents = currentTodos
        self.stubTodoUsecase.shouldFailCompleteTodo = shouldFailDoneTodo
        self.stubTodoUsecase.shouldFailMakeTodo = shouldFailMakeTodo
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.selectTimeZone(TimeZone(abbreviation: "KST")!)
        
        let viewModel = DayEventListViewModelImple(
            calendarSettingUsecase: calendarSettingUsecase,
            todoEventUsecase: self.stubTodoUsecase,
            eventTagUsecase: self.stubTagUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
    
    private func september10th() -> CurrentSelectDayModel {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        let component = DateComponents(year: 2023, month: 9, day: 10)
        let start = calendar.date(from: component)!.timeIntervalSince1970
        return .init(2023, 9, 10, weekId: "some", range: start..<start+3600*24)
    }
    
    private func september11th() -> CurrentSelectDayModel {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        let component = DateComponents(year: 2023, month: 9, day: 11)
        let start = calendar.date(from: component)!.timeIntervalSince1970
        return .init(2023, 9, 11, weekId: "some", range: start..<start+3600*24)
    }
}


extension DayEventListViewModelImpleTests {
    
    func testViewModel_provideSelectedDayTitle() {
        // given
        let expect = expectation(description: "선택된 날짜 정보 제공")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let selectedDays = self.waitOutputs(expect, for: viewModel.selectedDay) {
            viewModel.selectedDayChanaged(self.september10th(), and: [])
            viewModel.selectedDayChanaged(self.september11th(), and: [])
        }
        
        // then
        XCTAssertEqual(selectedDays, [
            "Sunday, Sep 10, 2023",
            "Monday, Sep 11, 2023"
        ])
    }
}

// current todo -> 상시
extension DayEventListViewModelImpleTests {
    
    func testCellViewModel_makeFromCurrentTodo() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        let current = TodoEvent(uuid: "curent", name: "current todo")
        let event = TodoCalendarEvent(current, in: timeZone)
        
        // when
        let cellViewModel = TodoEventCellViewModel(event, in: 0..<100, timeZone)
        
        // then
        XCTAssertEqual(cellViewModel?.name, "current todo")
        XCTAssertEqual(cellViewModel?.periodText, .singleText("Todo".localized()))
        XCTAssertEqual(cellViewModel?.periodDescription, nil)
    }
    
    func testCellViewModel_makeFromHoliday() {
        // given
        let holiday = Holiday(dateString: "2020-03-01", localName: "삼일절", name: "삼일절")
        let event = HolidayCalendarEvent(holiday, in: TimeZone(abbreviation: "KST")!)!
        
        // when
        let cellViewModel = HolidayEventCellViewModel(event)
        
        // then
        XCTAssertEqual(cellViewModel.name, "삼일절")
        XCTAssertEqual(cellViewModel.periodText, .singleText("Allday".localized()))
        XCTAssertEqual(cellViewModel.periodDescription, nil)
    }
    
    private func september10th(in timeZone: TimeZone) -> Range<TimeInterval> {
        let components = DateComponents(year: 2023, month: 9, day: 10)
        let caleandr = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let date = caleandr.date(from: components)!
        let start = caleandr.startOfDay(for: date)
        let end = caleandr.endOfDay(for: date)!
        return start.timeIntervalSince1970..<end.timeIntervalSince1970
    }
    
    private func september10th10_30AtTime(in timeZone: TimeZone) -> EventTime {
        let component = DateComponents(year: 2023, month: 9, day: 10, hour: 10, minute: 30)
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let date = calendar.date(from: component)!
        return .at(date.timeIntervalSince1970)
    }
    
    private var todayRange: Range<TimeInterval> {
        return september10th(in: TimeZone(abbreviation: "KST")!)
    }
    
    private var rangeFromPastToToday: Range<TimeInterval> {
        return self.todayRange.shift(-100)
    }
    
    private var rangeFromTodayToFuture: Range<TimeInterval> {
        return self.todayRange.shift(100)
    }
    
    private var rangeFromPastToFuture: Range<TimeInterval> {
        let range = self.todayRange
        return range.lowerBound-100..<range.upperBound+100
    }
    
    private var rangeFromTodayToToday: Range<TimeInterval> {
        let range = self.todayRange
        return range.lowerBound+100..<range.upperBound-100
    }
    
    func testCellViewModel_makeFromTodoEventWithTime() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ range: Range<TimeInterval>?,
            _ expectPeriodText: EventPeriodText
        ) {
            let time = range.map { EventTime.period($0) }
            let todo = TodoEvent(uuid: "todo", name: "dummy") |> \.time .~ time
            let event = TodoCalendarEvent(todo, in: timeZone)
            
            let cellViewModel = TodoEventCellViewModel(event, in: self.todayRange, timeZone)
            
            XCTAssertEqual(cellViewModel?.periodText, expectPeriodText)
        }
        // when + then
        parameterizeTest(nil, .singleText("Todo".localized()))
        parameterizeTest(self.rangeFromPastToToday, .doubleText("Todo".localized(), "23:58"))
        parameterizeTest(self.rangeFromTodayToFuture, .doubleText("Todo".localized(), "11 (Mon)"))
        parameterizeTest(self.rangeFromPastToFuture, .doubleText("Todo".localized(), "Allday".localized()))
        parameterizeTest(self.rangeFromTodayToToday, .doubleText("Todo".localized(), "23:58"))
    }
    
    func testCellViewModel_makeFromScheduleEventWithTime() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ range: Range<TimeInterval>,
            _ expectPeriodText: EventPeriodText
        ) {
            let time = EventTime.period(range)
            let schedule = ScheduleEvent(uuid: "event", name: "some", time: time)
            let event = ScheduleCalendarEvent.events(from: schedule, in: timeZone).first!
            
            let cellViewModel = ScheduleEventCellViewModel(event, in: self.todayRange, timeZone: timeZone)
            
            XCTAssertEqual(cellViewModel?.periodText, expectPeriodText)
        }
        // when + then
        parameterizeTest(self.rangeFromPastToToday, .doubleText("9 (Sat)", "23:58"))
        parameterizeTest(self.rangeFromTodayToFuture, .doubleText("0:01", "11 (Mon)"))
        parameterizeTest(self.rangeFromPastToFuture, .singleText("Allday".localized()))
        parameterizeTest(self.rangeFromTodayToToday, .doubleText("0:01", "23:58"))
    }
    
    func testCellViewModel_whenEventTimeIsAt_showTimeText() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        let time = self.september10th10_30AtTime(in: timeZone)
        let schedule = ScheduleEvent(uuid: "event", name: "name", time: time)
        let event = ScheduleCalendarEvent.events(from: schedule, in: timeZone).first!
        
        // when
        let cellViewModel = ScheduleEventCellViewModel(event, in: self.todayRange, timeZone: timeZone)
        
        // then
        XCTAssertEqual(cellViewModel?.periodText, .singleText("10:30"))
    }
    
    private var pdt9_10: Range<TimeInterval> {
        return september10th(in: TimeZone(abbreviation: "PDT")!)
    }
    private var pdt9_9to9_10: Range<TimeInterval> {
        let range = self.pdt9_10
        return range.lowerBound-24*3600..<range.upperBound
    }
    private var pdt9_10to9_11: Range<TimeInterval> {
        let range = self.pdt9_10
        return range.lowerBound..<range.upperBound+24*3600
    }
    private var pdt9_9to9_11: Range<TimeInterval> {
        let range = self.pdt9_10
        return range.lowerBound-24*3600..<range.upperBound+24*3600
    }
    
    func testCellViewModel_whenEventTimeIsAllDay_makeWithCurrentTimeZoneTimeShiftting() {
        // given
        let kstTimeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ range: Range<TimeInterval>,
            _ expectedPeriodText: EventPeriodText
        ) {
            let pdtSecondsFromGMT = TimeZone(abbreviation: "PDT")!.secondsFromGMT() |> TimeInterval.init
            let time = EventTime.allDay(range, secondsFromGMT: pdtSecondsFromGMT)
            let schedule = ScheduleEvent(uuid: "event", name: "some", time: time)
            let event = ScheduleCalendarEvent.events(from: schedule, in: kstTimeZone).first!
            
            let cellViewModel = ScheduleEventCellViewModel(event, in: self.todayRange, timeZone: kstTimeZone)
            
            XCTAssertEqual(cellViewModel?.periodText, expectedPeriodText)
        }
        // when + then
        parameterizeTest(self.pdt9_9to9_10, .singleText("Allday".localized()))
        parameterizeTest(self.pdt9_9to9_11, .singleText("Allday".localized()))
        parameterizeTest(self.pdt9_10, .singleText("Allday".localized()))
        parameterizeTest(self.pdt9_10to9_11, .singleText("Allday".localized()))
    }
    
    func testCellViewModel_makeEventWithTimeHasPeriod_setPeriodDesription() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ time: EventTime,
            _ expectedDescription: String?
        ) {
            let schedule = ScheduleEvent(uuid: "event", name: "some", time: time)
            let event = ScheduleCalendarEvent.events(from: schedule, in: timeZone).first!
            
            let cellViewModel = ScheduleEventCellViewModel(event,in: self.todayRange, timeZone: timeZone)
            
            XCTAssertEqual(cellViewModel?.periodDescription, expectedDescription)
        }
        
        // when + then
        let timeAt = EventTime.at(self.todayRange.lowerBound)
        parameterizeTest(timeAt, nil)
        
        let periodHasDays: EventTime = .period(
            self.todayRange.lowerBound-24*3600*3..<self.todayRange.upperBound
        )
        parameterizeTest(periodHasDays, "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)")
        
        let periodHasNoDays: EventTime = .period(
            self.todayRange.lowerBound-12*3600..<self.todayRange.upperBound-20*3600+1
        )
        parameterizeTest(periodHasNoDays, "Sep 9 12:00 ~ Sep 10 04:00(16hours)")
        
        let periodOnyHasMinutes: EventTime = .period(
            self.todayRange.lowerBound..<self.todayRange.lowerBound+10*60
        )
        parameterizeTest(periodOnyHasMinutes, "Sep 10 00:00 ~ Sep 10 00:10(10minutes)")
        
        let pdtTimeZone = TimeZone(abbreviation: "PDT")!
        let offset = pdtTimeZone.secondsFromGMT() |> TimeInterval.init
        let allDayToday: EventTime = .allDay(self.pdt9_10, secondsFromGMT: offset)
        parameterizeTest(allDayToday, nil)
        
        let allDay2Days: EventTime = .allDay(self.pdt9_9to9_10, secondsFromGMT: offset)
        parameterizeTest(allDay2Days, "Sep 9 ~ Sep 10(2days)")
    }
}

extension DayEventListViewModelImpleTests {
    
    private var dummyCurrentDay: CurrentSelectDayModel {
        return .init(2023, 09, 10, weekId: "week_1", range: self.todayRange)
    }
    
    private var dummyEvents: [any CalendarEvent] {
        let timeZone = TimeZone(abbreviation: "KST")!
        let holiday = HolidayCalendarEvent(.init(dateString: "2023-09-30", localName: "holiday", name: "holiday"), in: timeZone)!
        let schedule4 = ScheduleEvent(uuid: "repeating-schedule", name: "repeating-schedule", time: .at(0)) |> \.nextRepeatingTimes .~ [.init(time: .at(self.todayRange.lowerBound), turn: 4)]
            |> \.eventTagId .~ .custom("some")
        let scheduleWithRepeating = ScheduleCalendarEvent.events(from: schedule4, in: timeZone).last!
        let todo = TodoCalendarEvent(.init(uuid: ("todo-with-time"), name: "todo-with-time") |> \.eventTagId .~ .custom("some"), in: timeZone)
        let scheduleWithoutRepeating = ScheduleCalendarEvent(eventId: "not-repeating-schedule", name: "not-repeating-schedule", eventTime: .at(self.todayRange.lowerBound), eventTimeOnCalendar: nil, eventTagId: .custom("some")) |> \.turn .~ 1
        return [
            holiday, scheduleWithRepeating, todo, scheduleWithoutRepeating
        ]
    }
    
    private var dummyEventIdStrings: [String] {
        return [
            "2023-09-30-holiday",
            "repeating-schedule-4",
            "todo-with-time",
            "not-repeating-schedule"
        ]
    }
    
    // 선택된 날짜에 해당하는 이벤트 리스트 제공 + 이경우에 current todo 정보도 같이 제공
    func testViewModel_provideEventListThatDayWithCurrentTodo() {
        // given
        let expect = expectation(description: "해당 하는 날짜의 이벤트 목록을 current todo와 함께 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEvents.count + 2 })
        let cvms = self.waitFirstOutput(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEvents)
        }
        
        // then
        let eventIdLists = cvms?.map { $0.eventIdentifier }
        XCTAssertEqual(eventIdLists, [
            "current-todo-1", "current-todo-2"
        ] + self.dummyEventIdStrings)
    }
    
    // 선택된 날짜에 해당하는 todo event 완료 처리시 목록에서 제거
    func testViewModel_whenDoneTodo_exclude() {
        // given
        let expect = expectation(description: "todo 완료시 리스트에서 제거")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEvents.count + 2 })
        let cvmLists = self.waitOutputs(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEvents)
            
            viewModel.doneTodo("todo-with-time")
            // 완료처리되면 외부에서도 아이디 업데이트되어서 입력될꺼임
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEvents.filter { $0.eventId != "todo-with-time" })
        }
        
        // then
        let idLists = cvmLists.map { cvms in cvms.map { $0.eventIdentifier } }
        let expectIdListsBeforeDone = ["current-todo-1", "current-todo-2"] + self.dummyEventIdStrings
        let expectIdListsAfterDone = ["current-todo-1", "current-todo-2"] + self.dummyEventIdStrings.filter { $0 != "todo-with-time" }
        XCTAssertEqual(idLists, [
            expectIdListsBeforeDone,
            expectIdListsAfterDone
        ])
    }
    
    func testViewModel_whenFailToDoneTodo_showErrorWithoutUpdateList() {
        // given
        let expect = expectation(description: "todo 완료처리 실패시 에러 알림")
        let viewModel = self.makeViewModel(shouldFailDoneTodo: true)
        
        // when
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEvents.count + 2})
        let _ = self.waitFirstOutput(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEvents)
            
            viewModel.doneTodo("todo-with-time")
        }
        
        // then
        XCTAssertNotNil(self.spyRouter.didShowError)
    }
    
    private func makeViewModelWithInitialListLoaded(
        shouldFailDoneTodo: Bool = false,
        shouldFailMakeTodo: Bool = false
    ) -> DayEventListViewModelImple {
        // given
        let expect = expectation(description: "wait first cells loaded")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel(
            shouldFailDoneTodo: shouldFailDoneTodo,
            shouldFailMakeTodo: shouldFailMakeTodo
        )
        
        // when
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEvents.count + 2 })
        let _ = self.waitFirstOutput(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEvents)
        }
        
        // then
        return viewModel
    }
    
    func testViewModel_whenAfterFailToDoneTodo_notifyFailedId() {
        // given
        let expect = expectation(description: "todo 완료처리 실패시에 실패한 아이디 todo 알림")
        let viewModel = self.makeViewModelWithInitialListLoaded(shouldFailDoneTodo: true)
        
        // when
        let failedId = self.waitFirstOutput(expect, for: viewModel.doneTodoFailed) {
            viewModel.doneTodo("todo-with-time")
        }
        
        // then
        XCTAssertEqual(failedId, "todo-with-time")
    }
    
    func testViewModel_provideEventListWithoutOffTagEvent() {
        // given
        let expect = expectation(description: "이벤트 목록 제공시에 비활성화된 태그에 해당하는 이벤트는 제외")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            self.stubTagUsecase.toggleEventTagIsOnCalendar(.default)
        }
        
        // then
        let hasCurrentTodo = cvmLists
            .map { $0.filter { $0.name.starts(with: "current-todo") }}
            .map { !$0.isEmpty }
        XCTAssertEqual(hasCurrentTodo, [true, false])
    }
}

// MARK: - test make new todo quickly

extension DayEventListViewModelImpleTests {
    
    private var totalEventNameListWithoutPending: [String] {
        return [
            "current-todo-1", "current-todo-2",
            "holiday",
            "repeating-schedule",
            "todo-with-time",
            "not-repeating-schedule"
        ]
    }
    
    private var totalEventNameListsWithPending: [String] {
        return [
            "current-todo-1", "current-todo-2",
            "pending-quick-todo",
            "holiday",
            "repeating-schedule",
            "todo-with-time",
            "not-repeating-schedule"
        ]
    }
    
    func testViewModel_whenMakeNewTodoQuickly_appendPendingCellAndInvalidate() {
        // given
        let expect = expectation(description: "빠르게 todo 생성시에 pendingcell 방출하고 이후 제거")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.addNewTodoQuickly(withName: "pending-quick-todo")
        }
        
        // then
        let nameLists = cvmLists.map { $0.map { $0.name } }
        XCTAssertEqual(nameLists, [
            self.totalEventNameListWithoutPending,
            self.totalEventNameListsWithPending,
            self.totalEventNameListWithoutPending
        ])
    }
    
    func testViewModel_whenMakeNewTodoQuicklyFails_removePendingTodo() {
        // given
        let expect = expectation(description: "빠르게 todo 생성 실패시에도 pendingcell 방출하고 이후 제거")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithInitialListLoaded(shouldFailMakeTodo: true)
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.addNewTodoQuickly(withName: "pending-quick-todo")
        }
        
        // then
        let nameLists = cvmLists.map { $0.map { $0.name } }
        XCTAssertEqual(nameLists, [
            self.totalEventNameListWithoutPending,
            self.totalEventNameListsWithPending,
            self.totalEventNameListWithoutPending
        ])
    }
    
    func testViewModel_whenMakeNewTodoQuicklyFails_showError() {
        // given
        let expect = expectation(description: "빠르게 todo 생성 실패시에 에러 알림")
        let viewModel = self.makeViewModel(shouldFailMakeTodo: true)
        self.spyRouter.didShowErrorCallback = { _ in
            expect.fulfill()
        }
        // when
        viewModel.addNewTodoQuickly(withName: "pending-quick-todo")
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
}

// MARK: - test make events

extension DayEventListViewModelImpleTests {
    
    func testViewModel_makeTodoWithGivenName() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.makeTodoEvent(with: "some")
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToMakeNewTodoEventWithParams?.name, "some")
    }
    
    // TODO: evnet 생성 기능 추가한 이후에 구현
//    func testViewModel_makeNewEvent() {
//
//    }
//
//    func testViewModel_makeNewEventUsingTemplate() {
//        // given
//        // when
//        // then
//    }
}

extension DayEventListViewModelImpleTests {
    
    private class SpyRouter: BaseSpyRouter, DayEventListRouting, @unchecked Sendable {
        
        var didRouteToMakeNewTodoEventWithParams: TodoMakeParams?
        func routeToMakeTodoEvent(_ withParams: TodoMakeParams) {
            self.didRouteToMakeNewTodoEventWithParams = withParams
        }
        
        func routeToMakeNewEvent() {
            
        }
        
        func routeToSelectTemplateForMakeEvent() {
            
        }
    }
}
