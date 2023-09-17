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
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubTodoUsecase = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubTodoUsecase = nil
        self.spyRouter = nil
    }
    
    // 9-10일: current-todo-1, current-todo-2, todo-with-time, not-repeating-schedule, repeating-schedule(turn 4)
    // 9-11일: current-todo-1, current-todo-2
    private func makeViewModel(
        shouldFailDoneTodo: Bool = false
    ) -> DayEventListViewModelImple {
        let currentTodos: [TodoEvent] = [
            .init(uuid: "current-todo-1", name: "some"),
            .init(uuid: "current-todo-2", name: "some")
        ]
        let todoWithTime = TodoEvent(uuid: "todo-with-time", name: "some")
        let notRepeatingSchedule = ScheduleEvent(uuid: "not-repeating-schedule", name: "some", time: .at(self.todayRange.lowerBound))
        let repeatingSchedule = ScheduleEvent(uuid: "repeating-schedule", name: "some", time: .at(0)) |> \.nextRepeatingTimes .~ [.init(time: .at(self.todayRange.lowerBound), turn: 4)]
        
        self.stubTodoUsecase.stubCurrentTodoEvents = currentTodos
        self.stubTodoUsecase.stubTodoEventsInRange = [todoWithTime]
        self.stubTodoUsecase.shouldFailCompleteTodo = shouldFailDoneTodo
        
        let scheduleUsecase = StubScheduleEventUsecase()
        scheduleUsecase.stubScheduleEventsInRange = [notRepeatingSchedule, repeatingSchedule]
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.selectTimeZone(TimeZone(abbreviation: "KST")!)
        
        let viewModel = DayEventListViewModelImple(
            calendarSettingUsecase: calendarSettingUsecase,
            todoEventUsecase: self.stubTodoUsecase,
            scheduleEventUsecase: scheduleUsecase,
            eventTagUsecase: StubEventTagUsecase()
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
            viewModel.selectedDayChanaged(self.september10th(), and: [
                .todo("todo-with-time"), .schedule("not-repeating-schedule", turn: 1),  .schedule("repeating-schedule", turn: 4)
            ])
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
        let current = TodoEvent(uuid: "curent", name: "current todo")
        
        // when
        let cellViewModel = TodoEventCellViewModelImple(current, in: 0..<100, TimeZone(abbreviation: "KST")!)
        
        // then
        XCTAssertEqual(cellViewModel?.name, "current todo")
        XCTAssertEqual(cellViewModel?.periodText, .anyTime)
        XCTAssertEqual(cellViewModel?.periodDescription, nil)
    }
    
    func testCellViewModel_makeFromHoliday() {
        // given
        let holiday = Holiday(dateString: "2020-03-01", localName: "삼일절", name: "삼일절")
        
        // when
        let cellViewModel = HolidayEventCellViewModelImple(holiday)
        
        // then
        XCTAssertEqual(cellViewModel.name, "삼일절")
        XCTAssertEqual(cellViewModel.periodText, .allDay)
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
    
    func testCellViewModel_makeFromEventWithTime() {
        // given
        func parameterizeTest(
            _ range: Range<TimeInterval>,
            _ expectPeriodText: EventPeriodText
        ) {
            let time = EventTime.period(range)
            let event = ScheduleEvent(uuid: "event", name: "some", time: time)
            
            let cellViewModel = ScheduleEventCellViewModelImple(event, turn: 1, in: self.todayRange, timeZone: TimeZone(abbreviation: "KST")!)
            
            XCTAssertEqual(cellViewModel?.periodText, expectPeriodText)
        }
        // when + then
        parameterizeTest(self.rangeFromPastToToday, .fromPastToToday("9 (Sat)", "23:58"))
        parameterizeTest(self.rangeFromTodayToFuture, .fromTodayToFuture("0:01", "11 (Mon)"))
        parameterizeTest(self.rangeFromPastToFuture, .allDay)
        parameterizeTest(self.rangeFromTodayToToday, .inToday("0:01", "23:58"))
    }
    
    func testCellViewModel_whenEventTimeIsAt_showTimeText() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        let time = self.september10th10_30AtTime(in: timeZone)
        let event = ScheduleEvent(uuid: "event", name: "name", time: time)
        
        // when
        let cellViewModel = ScheduleEventCellViewModelImple(event, turn: 1, in: self.todayRange, timeZone: timeZone)
        
        // then
        XCTAssertEqual(cellViewModel?.periodText, .atTime("10:30"))
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
        func parameterizeTest(
            _ range: Range<TimeInterval>,
            _ expectedPeriodText: EventPeriodText
        ) {
            let pdtSecondsFromGMT = TimeZone(abbreviation: "PDT")!.secondsFromGMT() |> TimeInterval.init
            let time = EventTime.allDay(range, secondsFromGMT: pdtSecondsFromGMT)
            let event = ScheduleEvent(uuid: "event", name: "some", time: time)
            
            let cellViewModel = ScheduleEventCellViewModelImple(event, turn: 1, in: self.todayRange, timeZone: TimeZone(abbreviation: "KST")!)
            
            XCTAssertEqual(cellViewModel?.periodText, expectedPeriodText)
        }
        // when + then
        parameterizeTest(self.pdt9_9to9_10, .allDay)
        parameterizeTest(self.pdt9_9to9_11, .allDay)
        parameterizeTest(self.pdt9_10, .allDay)
        parameterizeTest(self.pdt9_10to9_11, .allDay)
    }
    
    func testCellViewModel_makeEventWithTimeHasPeriod_setPeriodDesription() {
        // given
        func parameterizeTest(
            _ time: EventTime,
            _ expectedDescription: String?
        ) {
            let schedule = ScheduleEvent(uuid: "event", name: "some", time: time)
            
            let cellViewModel = ScheduleEventCellViewModelImple(schedule, turn: 1, in: self.todayRange, timeZone: TimeZone(abbreviation: "KST")!)
            
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
    
    private var dummyEventIds: [EventId] {
        return [
            .holiday(.init(dateString: "dummy-date", localName: "holiday", name: "name")),
            .schedule("repeating-schedule", turn: 4),
            .todo("todo-with-time"),
            .schedule("not-repeating-schedule", turn: 1)
        ]
    }
    
    private var dummyEventIdStrings: [String] {
        return [
            "dummy-date_name",
            "repeating-schedule",
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
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEventIds.count + 2 })
        let cvms = self.waitFirstOutput(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEventIds)
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
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEventIds.count + 2 })
        let cvmLists = self.waitOutputs(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEventIds)
            
            viewModel.doneTodo("todo-with-time")
            // 완료처리되면 외부에서도 아이디 업데이트되어서 입력될꺼임
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEventIds.filter { $0 != .todo("todo-with-time") })
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
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEventIds.count + 2})
        let _ = self.waitFirstOutput(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEventIds)
            
            viewModel.doneTodo("todo-with-time")
        }
        
        // then
        XCTAssertNotNil(self.spyRouter.didShowError)
    }
    
    private func makeViewModelWithInitialListLoaded(
        shouldFailDoneTodo: Bool = false
    ) -> DayEventListViewModelImple {
        // given
        let expect = expectation(description: "wait first cells loaded")
        let viewModel = self.makeViewModel(shouldFailDoneTodo: shouldFailDoneTodo)
        
        // when
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEventIds.count + 2 })
        let _ = self.waitFirstOutput(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEventIds)
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
}

extension DayEventListViewModelImpleTests {
    
    private class SpyRouter: BaseSpyRouter, DayEventListRouting, @unchecked Sendable {
        
        
    }
}
